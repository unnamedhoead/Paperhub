package com.example.paperhub.websocket;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.net.URI;
import java.util.Map;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("ChatWebSocketHandler")
class ChatWebSocketHandlerTest {

    private ChatWebSocketHandler handler;

    @BeforeEach
    void setUp() {
        handler = new ChatWebSocketHandler();
    }

    // ── Multi-device support ──────────────────────────────────────────────

    @Nested
    @DisplayName("multi-device")
    class MultiDevice {

        @Test
        @DisplayName("should support multiple devices for same user")
        void shouldSupportMultipleDevices() throws Exception {
            WebSocketSession phone = mockChatSession("s1", 1L);
            WebSocketSession desktop = mockChatSession("s2", 1L);

            handler.afterConnectionEstablished(phone);
            handler.afterConnectionEstablished(desktop);

            handler.sendToUser(1L, Map.of("type", "new_message"));

            verify(phone).sendMessage(any(TextMessage.class));
            verify(desktop).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should not lose other device sessions when one disconnects")
        void shouldNotLoseOtherDevices() throws Exception {
            WebSocketSession phone = mockChatSession("s1", 1L);
            WebSocketSession desktop = mockChatSession("s2", 1L);

            handler.afterConnectionEstablished(phone);
            handler.afterConnectionEstablished(desktop);
            handler.afterConnectionClosed(phone, CloseStatus.NORMAL);

            handler.sendToUser(1L, Map.of("type", "new_message"));

            verify(desktop).sendMessage(any(TextMessage.class));
            verify(phone, never()).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should clean up user entry when last device disconnects")
        void shouldCleanUpWhenLastDeviceDisconnects() throws Exception {
            WebSocketSession session = mockChatSession("s1", 1L);
            handler.afterConnectionEstablished(session);
            handler.afterConnectionClosed(session, CloseStatus.NORMAL);

            assertThatCode(() -> handler.sendToUser(1L, Map.of("type", "test")))
                    .doesNotThrowAnyException();
        }
    }

    // ── Path and lifecycle ────────────────────────────────────────────────

    @Nested
    @DisplayName("lifecycle")
    class Lifecycle {

        @Test
        @DisplayName("should handle null URI gracefully")
        void shouldHandleNullUri() throws Exception {
            WebSocketSession session = mock(WebSocketSession.class);
            when(session.getId()).thenReturn("s_null");
            when(session.getUri()).thenReturn(null);

            assertThatCode(() -> handler.afterConnectionEstablished(session))
                    .doesNotThrowAnyException();
        }

        @Test
        @DisplayName("should respond to ping with pong")
        void shouldRespondToPing() throws Exception {
            WebSocketSession session = mockChatSession("s1", 1L);
            handler.afterConnectionEstablished(session);

            handler.handleTextMessage(session, new TextMessage("ping"));

            verify(session).sendMessage(argThat(msg ->
                    msg instanceof TextMessage && ((TextMessage) msg).getPayload().equals("pong")));
        }

        @Test
        @DisplayName("should send to all specified users")
        void shouldSendToAllUsers() throws Exception {
            WebSocketSession s1 = mockChatSession("s1", 1L);
            WebSocketSession s2 = mockChatSession("s2", 2L);
            WebSocketSession s3 = mockChatSession("s3", 3L);

            handler.afterConnectionEstablished(s1);
            handler.afterConnectionEstablished(s2);
            handler.afterConnectionEstablished(s3);

            handler.sendToUsers(java.util.List.of(1L, 2L), Map.of("type", "new_message"));

            verify(s1).sendMessage(any(TextMessage.class));
            verify(s2).sendMessage(any(TextMessage.class));
            verify(s3, never()).sendMessage(any(TextMessage.class));
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private static WebSocketSession mockChatSession(String sessionId, Long userId) {
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.getId()).thenReturn(sessionId);
        when(session.getUri()).thenReturn(URI.create("http://localhost/ws/chat/" + userId));
        when(session.isOpen()).thenReturn(true);
        return session;
    }
}
