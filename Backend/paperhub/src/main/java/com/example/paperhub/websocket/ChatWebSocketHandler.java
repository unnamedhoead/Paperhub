package com.example.paperhub.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.net.URI;
import java.time.Instant;
import java.util.Collection;
import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Chat WebSocket handler — one connection per device, multi-device per user.
 * <p>
 * Path: {@code /ws/chat/{userId}} (see {@link WsPaths#CHAT_TPL}).
 * </p>
 */
@Component
public class ChatWebSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(ChatWebSocketHandler.class);

    /** Max idle time before a session is considered a zombie (millis). */
    private static final long SESSION_TTL_MS = 90_000L;

    // userId -> (sessionId -> session) — supports multiple devices per user
    private final Map<Long, Map<String, WebSocketSession>> userSessions = new ConcurrentHashMap<>();

    private final ObjectMapper objectMapper = new ObjectMapper();

    // ── Connection lifecycle ──────────────────────────────────────────────

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String path = safePath(session);
        if (path == null) {
            log.warn("Chat WebSocket connected without URI, closing: sessionId={}", session.getId());
            closeQuietly(session, CloseStatus.BAD_DATA);
            return;
        }

        Long userId = extractUserId(path);
        if (userId != null) {
            userSessions.computeIfAbsent(userId, k -> new ConcurrentHashMap<>())
                    .put(session.getId(), session);
            log.info("Chat WebSocket connected: userId={}, sessionId={}", userId, session.getId());
        } else {
            log.warn("Chat WebSocket connected with invalid path: {}", path);
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String path = safePath(session);
        if (path == null) {
            return;
        }
        Long userId = extractUserId(path);
        if (userId != null) {
            Map<String, WebSocketSession> sessions = userSessions.get(userId);
            if (sessions != null) {
                sessions.remove(session.getId());
                if (sessions.isEmpty()) {
                    userSessions.remove(userId);
                }
            }
            log.debug("Chat WebSocket disconnected: userId={}, sessionId={}", userId, session.getId());
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        String payload = message.getPayload();
        if ("ping".equals(payload) || "PING".equals(payload)) {
            try {
                if (session.isOpen()) {
                    session.sendMessage(new TextMessage("pong"));
                }
            } catch (IOException e) {
                log.debug("Failed to send pong to chat session={}", session.getId());
            }
        }
        // Other client-to-server messages (e.g. typing indicators) can be
        // handled here if needed.
    }

    // ── Send API ──────────────────────────────────────────────────────────

    /** Send a message to all devices of a single user. */
    public void sendToUser(Long userId, Object message) {
        Map<String, WebSocketSession> sessions = userSessions.get(userId);
        if (sessions != null && !sessions.isEmpty()) {
            broadcastToSessions(sessions.values(), message);
        }
    }

    /** Send a message to all devices of multiple users. */
    public void sendToUsers(Iterable<Long> userIds, Object message) {
        for (Long userId : userIds) {
            sendToUser(userId, message);
        }
    }

    // ── Internal helpers ──────────────────────────────────────────────────

    private void broadcastToSessions(Collection<WebSocketSession> sessions, Object message) {
        String json;
        try {
            json = objectMapper.writeValueAsString(message);
        } catch (Exception e) {
            log.error("Failed to serialise chat WebSocket message: {}", e.getMessage(), e);
            return;
        }
        TextMessage textMessage = new TextMessage(json);
        for (WebSocketSession session : sessions) {
            try {
                if (session.isOpen()) {
                    session.sendMessage(textMessage);
                }
            } catch (IOException e) {
                log.debug("Failed to send to chat session={}: {}", session.getId(), e.getMessage());
            }
        }
    }

    private static Long extractUserId(String path) {
        // /ws/chat/{userId}
        try {
            String[] parts = path.split("/");
            if (parts.length >= 4 && "chat".equals(parts[2])) {
                return Long.parseLong(parts[3]);
            }
        } catch (Exception ignored) {
            // malformed id
        }
        return null;
    }

    private static String safePath(WebSocketSession session) {
        URI uri = session.getUri();
        return uri != null ? uri.getPath() : null;
    }

    private static void closeQuietly(WebSocketSession session, CloseStatus status) {
        try {
            if (session.isOpen()) {
                session.close(status);
            }
        } catch (IOException ignored) {
            // best-effort
        }
    }

    // ── Zombie cleanup ────────────────────────────────────────────────────

    @Scheduled(fixedRate = 60_000)
    public void purgeZombieSessions() {
        Instant cutoff = Instant.now().minusMillis(SESSION_TTL_MS);
        Iterator<Map.Entry<Long, Map<String, WebSocketSession>>> outerIt = userSessions.entrySet().iterator();
        while (outerIt.hasNext()) {
            Map.Entry<Long, Map<String, WebSocketSession>> entry = outerIt.next();
            Map<String, WebSocketSession> inner = entry.getValue();
            inner.values().removeIf(session -> isZombie(session, cutoff));
            if (inner.isEmpty()) {
                outerIt.remove();
            }
        }
    }

    private static boolean isZombie(WebSocketSession session, Instant cutoff) {
        try {
            if (!session.isOpen()) return true;
            long lastAccess = session.getAttributes().containsKey("lastAccessTime")
                    ? (Long) session.getAttributes().get("lastAccessTime")
                    : System.currentTimeMillis();
            return lastAccess < cutoff.toEpochMilli();
        } catch (Exception e) {
            return true;
        }
    }
}
