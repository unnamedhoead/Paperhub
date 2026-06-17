package com.example.paperhub.chat;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.chat.dto.MessageResponse;
import com.example.paperhub.websocket.ChatWebSocketService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.redis.core.ListOperations;
import org.springframework.data.redis.core.RedisTemplate;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("ChatService")
class ChatServiceTest {

    @Mock private ConversationRepository conversationRepository;
    @Mock private ConversationParticipantRepository participantRepository;
    @Mock private MessageRepository messageRepository;
    @Mock private UserRepository userRepository;
    @Mock private ChatWebSocketService chatWebSocketService;
    @Mock private RedisTemplate<String, Object> redisTemplate;
    @Mock private ListOperations<String, Object> listOperations;

    private ChatService chatService;

    @BeforeEach
    void setUp() {
        chatService = new ChatService(conversationRepository, participantRepository,
                messageRepository, userRepository, chatWebSocketService, redisTemplate);
        when(redisTemplate.opsForList()).thenReturn(listOperations);
    }

    // ── doSendMessage kernel ──────────────────────────────────────────────

    @Nested
    @DisplayName("doSendMessage kernel")
    class DoSendMessage {

        @Test
        @DisplayName("should persist, cache, update timestamp, and push")
        void shouldExecuteFullPipeline() {
            User sender = userWithId(1L);
            Conversation conv = new Conversation();
            conv.setId(10L);

            when(userRepository.findById(1L)).thenReturn(Optional.of(sender));
            when(participantRepository.existsByConversationIdAndUserId(10L, 1L)).thenReturn(true);
            when(conversationRepository.findById(10L)).thenReturn(Optional.of(conv));
            when(messageRepository.save(any(Message.class))).thenAnswer(inv -> {
                Message m = inv.getArgument(0);
                m.setId(100L);
                return m;
            });
            when(participantRepository.findByConversationId(10L))
                    .thenReturn(Collections.emptyList());

            Message result = chatService.sendMessage(10L, 1L, "hello", MessageType.TEXT,
                    null, null, null);

            assertThat(result).isNotNull();
            assertThat(result.getId()).isEqualTo(100L);

            // Verify Redis cache
            verify(listOperations).rightPush(anyString(), any(Message.class));
            verify(listOperations).trim(anyString(), anyLong(), anyLong());

            // Verify conversation timestamp updated
            verify(conversationRepository).save(argThat(c -> c.getUpdatedAt() != null));

            // Verify WebSocket push attempted
            verify(chatWebSocketService).sendNewMessage(eq(10L), any(MessageResponse.class));
        }

        @Test
        @DisplayName("should return null when user is not a participant")
        void shouldReturnNullWhenNotParticipant() {
            User sender = userWithId(1L);
            when(userRepository.findById(1L)).thenReturn(Optional.of(sender));
            when(participantRepository.existsByConversationIdAndUserId(10L, 1L)).thenReturn(false);

            Message result = chatService.sendMessage(10L, 1L, "hello", MessageType.TEXT,
                    null, null, null);

            assertThat(result).isNull();
            verify(messageRepository, never()).save(any());
        }

        @Test
        @DisplayName("should return null when conversation not found")
        void shouldReturnNullWhenConversationNotFound() {
            User sender = userWithId(1L);
            when(userRepository.findById(1L)).thenReturn(Optional.of(sender));
            when(participantRepository.existsByConversationIdAndUserId(10L, 1L)).thenReturn(true);
            when(conversationRepository.findById(10L)).thenReturn(Optional.empty());

            Message result = chatService.sendMessage(10L, 1L, "hello", MessageType.TEXT,
                    null, null, null);

            assertThat(result).isNull();
        }

        @Test
        @DisplayName("sendMessageWithMedia should set mediaUrls on message")
        void sendMessageWithMediaShouldSetMediaUrls() {
            User sender = userWithId(1L);
            Conversation conv = new Conversation();
            conv.setId(10L);
            List<String> urls = List.of("https://example.com/img1.jpg", "https://example.com/img2.jpg");

            when(userRepository.findById(1L)).thenReturn(Optional.of(sender));
            when(participantRepository.existsByConversationIdAndUserId(10L, 1L)).thenReturn(true);
            when(conversationRepository.findById(10L)).thenReturn(Optional.of(conv));
            when(messageRepository.save(any(Message.class))).thenAnswer(inv -> {
                Message m = inv.getArgument(0);
                m.setId(200L);
                return m;
            });
            when(participantRepository.findByConversationId(10L))
                    .thenReturn(Collections.emptyList());

            Message result = chatService.sendMessageWithMedia(10L, 1L, "check this",
                    MessageType.IMAGE, urls, "photo.jpg", 1024L);

            assertThat(result).isNotNull();
            assertThat(result.getMediaUrls()).containsExactlyElementsOf(urls);
            assertThat(result.getFileUrl()).isEqualTo(urls.get(0));
        }
    }

    // ── N+1: batch fetch senders ──────────────────────────────────────────

    @Nested
    @DisplayName("getConversationMessages (N+1 fix)")
    class GetConversationMessages {

        @Test
        @DisplayName("should batch-fetch senders instead of querying one-by-one")
        void shouldBatchFetchSenders() {
            when(participantRepository.existsByConversationIdAndUserId(10L, 1L)).thenReturn(true);

            User sender1 = userWithId(2L, "Alice", "alice.jpg");
            User sender2 = userWithId(3L, "Bob", "bob.jpg");

            Conversation conv = new Conversation();
            conv.setId(10L);

            Message msg1 = new Message();
            msg1.setId(1L); msg1.setConversation(conv); msg1.setSenderId(2L);
            msg1.setType(MessageType.TEXT); msg1.setContent("hi");
            msg1.setCreatedAt(LocalDateTime.now());

            Message msg2 = new Message();
            msg2.setId(2L); msg2.setConversation(conv); msg2.setSenderId(3L);
            msg2.setType(MessageType.TEXT); msg2.setContent("hey");
            msg2.setCreatedAt(LocalDateTime.now().minusMinutes(1));

            Page<Message> page = new PageImpl<>(List.of(msg1, msg2),
                    PageRequest.of(0, 20), 2);

            when(messageRepository.findByConversationIdOrderByCreatedAtDesc(eq(10L), any()))
                    .thenReturn(page);
            // batch fetch: findAllById with sender id set
            when(userRepository.findAllById(Set.of(2L, 3L)))
                    .thenReturn(List.of(sender1, sender2));

            Page<MessageResponse> result = chatService.getConversationMessages(10L, 1L, 0, 20);

            assertThat(result.getTotalElements()).isEqualTo(2);
            // Verify batch fetch was used
            verify(userRepository).findAllById(Set.of(2L, 3L));
            // Verify no individual findById calls
            verify(userRepository, never()).findById(anyLong());
        }
    }

    // ── Mute expiry ───────────────────────────────────────────────────────

    @Nested
    @DisplayName("ensureUserCanInteract (mute expiry)")
    class MuteExpiry {

        @Test
        @DisplayName("should throw when user is banned")
        void shouldThrowWhenBanned() {
            User banned = new User();
            banned.setId(1L);
            banned.setStatus(UserStatus.BANNED);
            when(userRepository.findById(1L)).thenReturn(Optional.of(banned));

            assertThatThrownBy(() -> chatService.sendMessage(10L, 1L, "hello",
                    MessageType.TEXT, null, null, null))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("封禁");
        }

        @Test
        @DisplayName("should throw when user is muted and mute not expired")
        void shouldThrowWhenMuted() {
            User muted = new User();
            muted.setId(1L);
            muted.setStatus(UserStatus.MUTE);
            muted.setMuteUntil(Instant.now().plus(1, ChronoUnit.HOURS));
            when(userRepository.findById(1L)).thenReturn(Optional.of(muted));

            assertThatThrownBy(() -> chatService.sendMessage(10L, 1L, "hello",
                    MessageType.TEXT, null, null, null))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("禁言");
        }

        @Test
        @DisplayName("should auto-restore NORMAL when mute has expired")
        void shouldRestoreNormalWhenMuteExpired() {
            User muted = new User();
            muted.setId(1L);
            muted.setStatus(UserStatus.MUTE);
            muted.setMuteUntil(Instant.now().minus(1, ChronoUnit.HOURS)); // expired
            when(userRepository.findById(1L)).thenReturn(Optional.of(muted));

            Conversation conv = new Conversation();
            conv.setId(10L);
            when(participantRepository.existsByConversationIdAndUserId(10L, 1L)).thenReturn(true);
            when(conversationRepository.findById(10L)).thenReturn(Optional.of(conv));
            when(messageRepository.save(any(Message.class))).thenAnswer(inv -> {
                Message m = inv.getArgument(0);
                m.setId(300L);
                return m;
            });
            when(participantRepository.findByConversationId(10L))
                    .thenReturn(Collections.emptyList());

            Message result = chatService.sendMessage(10L, 1L, "hello",
                    MessageType.TEXT, null, null, null);

            assertThat(result).isNotNull();

            // Verify user was restored to NORMAL
            ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
            verify(userRepository).save(userCaptor.capture());
            User saved = userCaptor.getValue();
            assertThat(saved.getStatus()).isEqualTo(UserStatus.NORMAL);
            assertThat(saved.getMuteUntil()).isNull();
        }
    }

    // ── Constructor injection completeness ────────────────────────────────

    @Test
    @DisplayName("should be constructable with all dependencies (no @Autowired)")
    void shouldHaveAllDependenciesInConstructor() {
        // If constructor injection compiles, it works.  This test exists to
        // document that all 6 dependencies are wired through the constructor.
        assertThat(chatService).isNotNull();
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private static User userWithId(Long id) {
        return userWithId(id, "User" + id, "avatar" + id + ".jpg");
    }

    private static User userWithId(Long id, String name, String avatar) {
        User u = new User();
        u.setId(id);
        u.setName(name);
        u.setAvatar(avatar);
        u.setStatus(UserStatus.NORMAL);
        return u;
    }
}
