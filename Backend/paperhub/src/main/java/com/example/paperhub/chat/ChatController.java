package com.example.paperhub.chat;

import com.example.paperhub.chat.dto.ConversationResponse;
import com.example.paperhub.chat.dto.CreateConversationRequest;
import com.example.paperhub.chat.dto.MessageResponse;
import com.example.paperhub.chat.dto.SendMessageRequest;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.config.ObsConfig;
import com.obs.services.ObsClient;
import com.obs.services.exception.ObsException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import jakarta.validation.Valid;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/conversations")
public class ChatController {

    private static final Logger log = LoggerFactory.getLogger(ChatController.class);

    private final ChatService chatService;
    private final UserRepository userRepository;
    private final ConversationParticipantRepository participantRepository;
    private final ObsClient obsClient;
    private final ObsConfig obsConfig;

    public ChatController(ChatService chatService,
                          UserRepository userRepository,
                          ConversationParticipantRepository participantRepository,
                          ObsClient obsClient,
                          ObsConfig obsConfig) {
        this.chatService = chatService;
        this.userRepository = userRepository;
        this.participantRepository = participantRepository;
        this.obsClient = obsClient;
        this.obsConfig = obsConfig;
    }

    // ── Conversation list ─────────────────────────────────────────────────

    @GetMapping
    public ResponseEntity<List<ConversationResponse>> getConversations(
            @AuthenticationPrincipal User user) {
        requireAuth(user);
        return ResponseEntity.ok(chatService.getUserConversations(user.getId()));
    }

    // ── Create / get conversation ─────────────────────────────────────────

    @PostMapping
    public ResponseEntity<ConversationResponse> createOrGetConversation(
            @AuthenticationPrincipal User currentUser,
            @Valid @RequestBody CreateConversationRequest request) {
        requireAuth(currentUser);

        User otherUser = userRepository.findById(request.getTargetUserId())
                .orElseThrow(() -> new BadRequestException("目标用户不存在"));

        Conversation conversation = chatService.createOrGetPrivateConversation(
                currentUser.getId(), request.getTargetUserId());

        ConversationResponse response = new ConversationResponse(
                conversation, null, 0,
                otherUser.getName(), otherUser.getAvatar(), false);

        return ResponseEntity.ok(response);
    }

    // ── Messages ──────────────────────────────────────────────────────────

    @GetMapping("/{conversationId}/messages")
    public ResponseEntity<Page<MessageResponse>> getMessages(
            @AuthenticationPrincipal User user,
            @PathVariable Long conversationId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "100") int size) {
        requireAuth(user);
        requireParticipant(conversationId, user.getId());

        return ResponseEntity.ok(chatService.getConversationMessages(conversationId, user.getId(), page, size));
    }

    @PostMapping("/{conversationId}/messages")
    public ResponseEntity<MessageResponse> sendMessage(
            @AuthenticationPrincipal User user,
            @PathVariable Long conversationId,
            @Valid @RequestBody SendMessageRequest request) {
        requireAuth(user);
        requireParticipant(conversationId, user.getId());

        Message message;
        if (request.getMediaUrls() != null && !request.getMediaUrls().isEmpty()) {
            message = chatService.sendMessageWithMedia(
                    conversationId, user.getId(),
                    request.getContent(),
                    request.getType() != null ? request.getType() : MessageType.IMAGE,
                    request.getMediaUrls(),
                    request.getFileName(),
                    request.getFileSize());
        } else {
            message = chatService.sendMessage(
                    conversationId, user.getId(),
                    request.getContent(),
                    request.getType() != null ? request.getType() : MessageType.TEXT,
                    request.getFileUrl(),
                    request.getFileName(),
                    request.getFileSize());
        }

        if (message == null) {
            throw new BadRequestException("消息发送失败");
        }

        MessageResponse response = new MessageResponse(message);
        response.setSenderName(user.getName());
        response.setSenderAvatar(user.getAvatar());
        response.setIsMe(true);

        return ResponseEntity.ok(response);
    }

    // ── Read status ───────────────────────────────────────────────────────

    @PutMapping("/{conversationId}/read")
    public ResponseEntity<Map<String, Object>> markAsRead(
            @AuthenticationPrincipal User user,
            @PathVariable Long conversationId) {
        requireAuth(user);
        requireParticipant(conversationId, user.getId());

        chatService.markAsRead(conversationId, user.getId());
        return ResponseEntity.ok(Map.of("success", true));
    }

    // ── Latest messages (Redis-first) ─────────────────────────────────────

    @GetMapping("/{conversationId}/messages/latest")
    public ResponseEntity<List<MessageResponse>> getLatestMessages(
            @AuthenticationPrincipal User user,
            @PathVariable Long conversationId,
            @RequestParam(defaultValue = "30") int limit) {
        requireAuth(user);
        requireParticipant(conversationId, user.getId());

        return ResponseEntity.ok(chatService.getLatestMessages(conversationId, user.getId(), limit));
    }

    // ── Voice message upload ──────────────────────────────────────────────

    @PostMapping("/{conversationId}/messages/voice")
    public ResponseEntity<?> uploadVoiceMessage(
            @AuthenticationPrincipal User currentUser,
            @PathVariable Long conversationId,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "duration", required = false, defaultValue = "0") Long duration) {
        requireAuth(currentUser);
        requireParticipant(conversationId, currentUser.getId());

        if (file == null || file.isEmpty()) {
            throw new BadRequestException("语音文件不能为空");
        }

        String originalName = file.getOriginalFilename();
        String extension = StringUtils.hasText(originalName) && originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.'))
                : "";

        if (!isAudioFile(extension)) {
            throw new BadRequestException("不支持的音频格式");
        }
        if (file.getSize() > 10 * 1024 * 1024) {
            throw new BadRequestException("语音文件不能超过10MB");
        }

        String objectKey = "chat-voice/" + UUID.randomUUID() + extension;
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + objectKey;

        try {
            obsClient.putObject(obsConfig.getBucketName(), objectKey, file.getInputStream());
            log.info("Voice file uploaded: {}", url);
        } catch (ObsException e) {
            log.error("OBS upload failed: {}", e.getErrorMessage(), e);
            throw new RuntimeException("文件上传失败: " + e.getErrorMessage(), e);
        } catch (IOException e) {
            log.error("File read failed: {}", e.getMessage(), e);
            throw new RuntimeException("文件读取失败: " + e.getMessage(), e);
        }

        Message message = chatService.sendMessage(
                conversationId, currentUser.getId(),
                "", MessageType.VOICE,
                url, originalName, file.getSize());

        if (message == null) {
            throw new BadRequestException("消息发送失败");
        }

        MessageResponse response = new MessageResponse(message);
        response.setSenderName(currentUser.getName());
        response.setSenderAvatar(currentUser.getAvatar());
        response.setIsMe(true);

        return ResponseEntity.ok(response);
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    private void requireAuth(User user) {
        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
    }

    private void requireParticipant(Long conversationId, Long userId) {
        if (!participantRepository.existsByConversationIdAndUserId(conversationId, userId)) {
            throw new ForbiddenException("无权限访问此会话");
        }
    }

    private boolean isAudioFile(String extension) {
        String lowerExt = extension.toLowerCase();
        return lowerExt.equals(".mp3") || lowerExt.equals(".wav") || lowerExt.equals(".m4a") ||
               lowerExt.equals(".ogg") || lowerExt.equals(".aac") || lowerExt.equals(".webm");
    }
}
