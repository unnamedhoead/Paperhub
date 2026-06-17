package com.example.paperhub.chat;

import com.example.paperhub.chat.dto.ConversationResponse;
import com.example.paperhub.chat.dto.MessageResponse;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.websocket.ChatWebSocketService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
public class ChatService {

    private static final Logger log = LoggerFactory.getLogger(ChatService.class);

    private static final int CACHE_MESSAGE_LIMIT = 30;

    private final ConversationRepository conversationRepository;
    private final ConversationParticipantRepository conversationParticipantRepository;
    private final MessageRepository messageRepository;
    private final UserRepository userRepository;
    private final ChatWebSocketService chatWebSocketService;
    private final RedisTemplate<String, Object> redisTemplate;

    public ChatService(ConversationRepository conversationRepository,
                       ConversationParticipantRepository conversationParticipantRepository,
                       MessageRepository messageRepository,
                       UserRepository userRepository,
                       ChatWebSocketService chatWebSocketService,
                       RedisTemplate<String, Object> redisTemplate) {
        this.conversationRepository = conversationRepository;
        this.conversationParticipantRepository = conversationParticipantRepository;
        this.messageRepository = messageRepository;
        this.userRepository = userRepository;
        this.chatWebSocketService = chatWebSocketService;
        this.redisTemplate = redisTemplate;
    }

    // ── Conversation ──────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public List<ConversationResponse> getUserConversations(Long userId) {
        log.info("getUserConversations: userId={}", userId);
        List<Conversation> conversations = conversationRepository.findByUserId(userId);
        if (conversations.isEmpty()) {
            return Collections.emptyList();
        }

        // Batch-fetch other participants' user ids
        List<Long> conversationIds = conversations.stream()
                .map(Conversation::getId).collect(Collectors.toList());
        Map<Long, Long> convToOtherUser = resolveOtherParticipantsBatch(conversationIds, userId);

        // Batch-fetch User entities for the other participants
        Set<Long> otherUserIds = Set.copyOf(convToOtherUser.values());
        Map<Long, User> userMap = userRepository.findAllById(otherUserIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

        List<ConversationResponse> responses = new ArrayList<>();
        for (Conversation conv : conversations) {
            Long otherUserId = convToOtherUser.get(conv.getId());
            if (otherUserId == null) {
                log.warn("No other participant found for conversation={}", conv.getId());
                continue;
            }
            User otherUser = userMap.get(otherUserId);
            if (otherUser == null) {
                log.warn("User not found: userId={}", otherUserId);
                continue;
            }
            Message lastMessage = getLastMessage(conv.getId());
            Integer unreadCount = getUnreadCount(conv.getId(), userId);

            responses.add(new ConversationResponse(
                    conv, lastMessage, unreadCount,
                    otherUser.getName(), otherUser.getAvatar(), false));
        }
        log.info("Returning {} conversations for userId={}", responses.size(), userId);
        return responses;
    }

    @Transactional
    public Conversation createOrGetPrivateConversation(Long currentUserId, Long targetUserId) {
        ensureUserCanInteract(currentUserId);
        log.info("createOrGetPrivateConversation: currentUserId={}, targetUserId={}", currentUserId, targetUserId);

        Optional<Conversation> existing = conversationRepository
                .findPrivateConversationBetweenUsers(currentUserId, targetUserId);
        if (existing.isPresent()) {
            return existing.get();
        }

        Conversation conversation = new Conversation();
        conversation.setType(ConversationType.PRIVATE);
        conversation = conversationRepository.save(conversation);

        addParticipant(conversation, currentUserId);
        addParticipant(conversation, targetUserId);
        return conversation;
    }

    // ── Messages ──────────────────────────────────────────────────────────

    @Transactional
    public Page<MessageResponse> getConversationMessages(Long conversationId, Long userId, int page, int size) {
        if (!conversationParticipantRepository.existsByConversationIdAndUserId(conversationId, userId)) {
            return Page.empty();
        }
        markAsRead(conversationId, userId);

        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Message> messages = messageRepository.findByConversationIdOrderByCreatedAtDesc(conversationId, pageable);

        // Batch-fetch sender info to avoid N+1
        Set<Long> senderIds = messages.getContent().stream()
                .map(Message::getSenderId).collect(Collectors.toSet());
        Map<Long, User> userMap = userRepository.findAllById(senderIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));

        return messages.map(msg -> toMessageResponse(msg, userId, userMap));
    }

    /**
     * Send a plain message (no media).
     */
    @Transactional
    public Message sendMessage(Long conversationId, Long senderId, String content, MessageType type,
                               String fileUrl, String fileName, Long fileSize) {
        Message message = new Message();
        message.setContent(content);
        message.setType(type);
        message.setFileUrl(fileUrl);
        message.setFileName(fileName);
        message.setFileSize(fileSize);
        return doSendMessage(conversationId, senderId, message);
    }

    /**
     * Send a message with media URLs.
     */
    @Transactional
    public Message sendMessageWithMedia(Long conversationId, Long senderId, String content,
                                        MessageType type, List<String> mediaUrls, String fileName, Long fileSize) {
        Message message = new Message();
        message.setContent(content);
        message.setType(type);
        message.setMediaUrls(mediaUrls != null ? mediaUrls : new ArrayList<>());
        if (mediaUrls != null && !mediaUrls.isEmpty()) {
            message.setFileUrl(mediaUrls.get(0));
        }
        message.setFileName(fileName);
        message.setFileSize(fileSize);
        return doSendMessage(conversationId, senderId, message);
    }

    /**
     * Common kernel: validate, persist, cache, update timestamp, push.
     */
    private Message doSendMessage(Long conversationId, Long senderId, Message message) {
        ensureUserCanInteract(senderId);

        if (!conversationParticipantRepository.existsByConversationIdAndUserId(conversationId, senderId)) {
            log.warn("User {} not a participant of conversation {}", senderId, conversationId);
            return null;
        }

        Conversation conversation = conversationRepository.findById(conversationId).orElse(null);
        if (conversation == null) {
            log.warn("Conversation {} not found", conversationId);
            return null;
        }

        message.setConversation(conversation);
        message.setSenderId(senderId);
        message.setCreatedAt(LocalDateTime.now());

        Message saved = messageRepository.save(message);

        saveMessageToRedis(conversationId, saved);

        conversation.setUpdatedAt(LocalDateTime.now());
        conversationRepository.save(conversation);

        pushRealTimeMessage(conversationId, saved);

        return saved;
    }

    @Transactional
    public void markAsRead(Long conversationId, Long userId) {
        conversationParticipantRepository.updateLastReadAt(conversationId, userId, LocalDateTime.now());
    }

    // ── Latest messages (Redis-first) ─────────────────────────────────────

    @Transactional(readOnly = true)
    public List<MessageResponse> getLatestMessages(Long conversationId, Long userId, int limit) {
        if (!conversationParticipantRepository.existsByConversationIdAndUserId(conversationId, userId)) {
            return Collections.emptyList();
        }

        try {
            String key = RedisKeys.conversationMessages(conversationId);
            List<Object> cached = redisTemplate.opsForList().range(key, -limit, -1);
            if (cached != null && !cached.isEmpty()) {
                log.debug("Redis hit for conversation={}, count={}", conversationId, cached.size());
                List<Message> messages = cached.stream()
                        .filter(obj -> obj instanceof Message)
                        .map(obj -> (Message) obj)
                        .collect(Collectors.toList());
                return buildMessageResponses(messages, userId);
            }
        } catch (Exception e) {
            log.error("Failed to read messages from Redis for conversation={}: {}", conversationId, e.getMessage());
        }

        return loadFromMySQLAndCache(conversationId, userId, limit);
    }

    // ── Private helpers ───────────────────────────────────────────────────

    private List<MessageResponse> loadFromMySQLAndCache(Long conversationId, Long userId, int limit) {
        log.debug("Loading messages from MySQL for conversation={}", conversationId);
        Pageable pageable = PageRequest.of(0, limit, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<Message> page = messageRepository.findByConversationIdOrderByCreatedAtDesc(conversationId, pageable);
        List<Message> messageList = page.getContent();

        if (!messageList.isEmpty()) {
            try {
                String key = RedisKeys.conversationMessages(conversationId);
                redisTemplate.delete(key);
                for (int i = messageList.size() - 1; i >= 0; i--) {
                    redisTemplate.opsForList().rightPush(key, messageList.get(i));
                }
            } catch (Exception e) {
                log.error("Failed to cache messages to Redis for conversation={}: {}", conversationId, e.getMessage());
            }
        }

        return buildMessageResponses(messageList, userId);
    }

    /**
     * Build MessageResponse list with a single batch user lookup.
     */
    private List<MessageResponse> buildMessageResponses(List<Message> messages, Long userId) {
        if (messages.isEmpty()) return Collections.emptyList();
        Set<Long> senderIds = messages.stream().map(Message::getSenderId).collect(Collectors.toSet());
        Map<Long, User> userMap = userRepository.findAllById(senderIds).stream()
                .collect(Collectors.toMap(User::getId, Function.identity()));
        return messages.stream()
                .map(msg -> toMessageResponse(msg, userId, userMap))
                .collect(Collectors.toList());
    }

    private static MessageResponse toMessageResponse(Message message, Long currentUserId, Map<Long, User> userMap) {
        MessageResponse resp = new MessageResponse(message);
        User sender = userMap.get(message.getSenderId());
        if (sender != null) {
            resp.setSenderName(sender.getName());
            resp.setSenderAvatar(sender.getAvatar());
        }
        resp.setIsMe(message.getSenderId().equals(currentUserId));
        return resp;
    }

    private void pushRealTimeMessage(Long conversationId, Message message) {
        try {
            List<ConversationParticipant> participants = conversationParticipantRepository
                    .findByConversationId(conversationId);
            Long[] participantIds = participants.stream()
                    .map(ConversationParticipant::getUserId)
                    .toArray(Long[]::new);

            MessageResponse resp = new MessageResponse(message);
            // Fetch sender info for the push payload
            userRepository.findById(message.getSenderId()).ifPresent(user -> {
                resp.setSenderName(user.getName());
                resp.setSenderAvatar(user.getAvatar());
            });
            resp.setIsMe(false);

            chatWebSocketService.sendNewMessage(conversationId, resp, participantIds);
        } catch (Exception e) {
            log.error("WebSocket push failed for conversation={}, message={}: {}",
                    conversationId, message.getId(), e.getMessage(), e);
        }
    }

    private void saveMessageToRedis(Long conversationId, Message message) {
        try {
            String key = RedisKeys.conversationMessages(conversationId);
            redisTemplate.opsForList().rightPush(key, message);
            redisTemplate.opsForList().trim(key, -CACHE_MESSAGE_LIMIT, -1);
        } catch (Exception e) {
            log.error("Failed to save message to Redis: conversationId={}, error={}",
                    conversationId, e.getMessage());
        }
    }

    private Message getLastMessage(Long conversationId) {
        Pageable pageable = PageRequest.of(0, 1, Sort.by(Sort.Direction.DESC, "createdAt"));
        List<Message> messages = messageRepository.findLatestMessages(conversationId, pageable);
        return messages.isEmpty() ? null : messages.get(0);
    }

    private Integer getUnreadCount(Long conversationId, Long userId) {
        Long count = conversationRepository.countUnreadMessages(conversationId, userId);
        return count != null ? count.intValue() : 0;
    }

    private void addParticipant(Conversation conversation, Long userId) {
        ConversationParticipant participant = new ConversationParticipant();
        participant.setConversation(conversation);
        participant.setUserId(userId);
        participant.setJoinedAt(LocalDateTime.now());
        conversationParticipantRepository.save(participant);
    }

    /**
     * Batch resolve: for each conversation, find the other participant's user id.
     */
    private Map<Long, Long> resolveOtherParticipantsBatch(List<Long> conversationIds, Long currentUserId) {
        // Load all participants for these conversations in one round-trip would
        // require a new repository method.  For now we do it per conversation
        // but each is a single query — reasonable for typical conversation counts.
        return conversationIds.stream()
                .collect(Collectors.toMap(
                        Function.identity(),
                        convId -> getOtherParticipantIdByConvId(convId, currentUserId)));
    }

    private Long getOtherParticipantIdByConvId(Long conversationId, Long currentUserId) {
        List<ConversationParticipant> participants = conversationParticipantRepository
                .findByConversationId(conversationId);
        return participants.stream()
                .map(ConversationParticipant::getUserId)
                .filter(uid -> uid != null && !uid.equals(currentUserId))
                .findFirst()
                .orElse(null);
    }

    // ── Guard ─────────────────────────────────────────────────────────────

    private void ensureUserCanInteract(Long userId) {
        if (userId == null) {
            throw new IllegalArgumentException("未认证用户无法执行此操作");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));

        if (user.getStatus() == UserStatus.BANNED) {
            throw new IllegalArgumentException("账号已被封禁，无法发送私信");
        }
        if (user.getStatus() == UserStatus.MUTE) {
            Instant muteUntil = user.getMuteUntil();
            if (muteUntil != null && Instant.now().isAfter(muteUntil)) {
                // Mute has expired — auto-restore to NORMAL
                log.info("Mute expired for userId={}, restoring to NORMAL", userId);
                user.setStatus(UserStatus.NORMAL);
                user.setMuteUntil(null);
                userRepository.save(user);
                return;
            }
            throw new IllegalArgumentException("账号被禁言中，暂时无法发送私信");
        }
    }
}
