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
@DisplayName("SimpleWebSocketHandler")
class SimpleWebSocketHandlerTest {

    private SimpleWebSocketHandler handler;

    @BeforeEach
    void setUp() {
        handler = new SimpleWebSocketHandler();
    }

    // ── Path matching ─────────────────────────────────────────────────────

    @Nested
    @DisplayName("path routing")
    class PathRouting {

        @Test
        @DisplayName("should route /ws/admin to admin sessions")
        void shouldRouteAdmin() throws Exception {
            WebSocketSession session = mockSession("s1", "/ws/admin");
            handler.afterConnectionEstablished(session);

            handler.sendToAdmins(Map.of("type", "test"));

            verify(session).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should route /ws/posts/42 to post sessions")
        void shouldRoutePosts() throws Exception {
            WebSocketSession session = mockSession("s1", "/ws/posts/42");
            handler.afterConnectionEstablished(session);

            handler.sendToPost(42L, Map.of("type", "like_update", "likesCount", 5, "isLiked", true));

            verify(session).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should route /ws/notifications/7 to user sessions")
        void shouldRouteNotifications() throws Exception {
            WebSocketSession session = mockSession("s1", "/ws/notifications/7");
            handler.afterConnectionEstablished(session);

            handler.sendToUser(7L, Map.of("type", "new_notification"));

            verify(session).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should not match /admin inside another path segment")
        void shouldNotMatchAdminInOtherPath() throws Exception {
            // /ws/posts/admin123 should NOT be treated as admin
            WebSocketSession session = mockSession("s1", "/ws/posts/admin123");
            handler.afterConnectionEstablished(session);

            // sendToAdmins should NOT reach this session (it was registered as post)
            handler.sendToAdmins(Map.of("type", "test"));
            verify(session, never()).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should handle null URI gracefully")
        void shouldHandleNullUri() throws Exception {
            WebSocketSession session = mock(WebSocketSession.class);
            when(session.getId()).thenReturn("s_null");
            when(session.getUri()).thenReturn(null);

            assertThatCode(() -> handler.afterConnectionEstablished(session))
                    .doesNotThrowAnyException();
        }
    }

    // ── Broadcast logic ───────────────────────────────────────────────────

    @Nested
    @DisplayName("broadcast")
    class Broadcast {

        @Test
        @DisplayName("should serialize message once and send to all open sessions")
        void shouldSerializeOnceSendToAll() throws Exception {
            WebSocketSession s1 = mockSession("s1", "/ws/posts/1");
            WebSocketSession s2 = mockSession("s2", "/ws/posts/1");

            handler.afterConnectionEstablished(s1);
            handler.afterConnectionEstablished(s2);

            handler.sendToPost(1L, Map.of("type", "comment_created"));

            verify(s1).sendMessage(any(TextMessage.class));
            verify(s2).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should skip closed sessions gracefully")
        void shouldSkipClosedSessions() throws Exception {
            WebSocketSession s1 = mockSession("s1", "/ws/posts/1");
            WebSocketSession s2 = mockSession("s2", "/ws/posts/1");

            when(s1.isOpen()).thenReturn(false); // closed

            handler.afterConnectionEstablished(s1);
            handler.afterConnectionEstablished(s2);

            handler.sendToPost(1L, Map.of("type", "favorite_update"));

            verify(s1, never()).sendMessage(any(TextMessage.class));
            verify(s2).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should not throw when no sessions for post")
        void shouldNotThrowWhenNoSessions() {
            assertThatCode(() -> handler.sendToPost(999L, Map.of("type", "test")))
                    .doesNotThrowAnyException();
        }
    }

    // ── Session cleanup ───────────────────────────────────────────────────

    @Nested
    @DisplayName("session cleanup")
    class SessionCleanup {

        @Test
        @DisplayName("should remove session on close")
        void shouldRemoveOnClose() throws Exception {
            WebSocketSession session = mockSession("s1", "/ws/posts/42");
            handler.afterConnectionEstablished(session);
            handler.afterConnectionClosed(session, CloseStatus.NORMAL);

            // After removal, sendToPost should be a no-op
            handler.sendToPost(42L, Map.of("type", "test"));
            verify(session, never()).sendMessage(any(TextMessage.class));
        }

        @Test
        @DisplayName("should handle ping with pong")
        void shouldHandlePing() throws Exception {
            WebSocketSession session = mockSession("s1", "/ws/posts/42");
            handler.afterConnectionEstablished(session);

            handler.handleTextMessage(session, new TextMessage("ping"));

            verify(session).sendMessage(argThat(msg ->
                    msg instanceof TextMessage && ((TextMessage) msg).getPayload().equals("pong")));
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private static WebSocketSession mockSession(String id, String path) {
        WebSocketSession session = mock(WebSocketSession.class);
        when(session.getId()).thenReturn(id);
        when(session.getUri()).thenReturn(URI.create("http://localhost" + path));
        when(session.isOpen()).thenReturn(true);
        return session;
    }
}
