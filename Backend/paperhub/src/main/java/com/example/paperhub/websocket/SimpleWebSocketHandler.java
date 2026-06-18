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
 * Unified WebSocket handler for posts, admin, and user-notification streams.
 * <p>
 * Path routing (exact prefix match via {@link WsPaths}):
 * <ul>
 *   <li>{@code /ws/posts/{postId}}  — post-scoped updates (likes, comments, etc.)</li>
 *   <li>{@code /ws/admin}           — admin broadcast</li>
 *   <li>{@code /ws/notifications/{userId}} — per-user notification push</li>
 * </ul>
 * </p>
 */
@Component
public class SimpleWebSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(SimpleWebSocketHandler.class);

    /** Max idle time before a session is considered a zombie (millis). */
    private static final long SESSION_TTL_MS = 90_000L;

    // postId -> (sessionId -> session)
    private final Map<Long, Map<String, WebSocketSession>> postSessions = new ConcurrentHashMap<>();
    // sessionId -> session
    private final Map<String, WebSocketSession> adminSessions = new ConcurrentHashMap<>();
    // userId -> (sessionId -> session)
    private final Map<Long, Map<String, WebSocketSession>> userSessions = new ConcurrentHashMap<>();

    private final ObjectMapper objectMapper = new ObjectMapper();

    // ── Connection lifecycle ──────────────────────────────────────────────

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String path = safePath(session);
        if (path == null) {
            log.warn("WebSocket connected without URI, closing: sessionId={}", session.getId());
            closeQuietly(session, CloseStatus.BAD_DATA);
            return;
        }

        if (path.startsWith(WsPaths.ADMIN)) {
            adminSessions.put(session.getId(), session);
            log.info("Admin WebSocket connected: sessionId={}", session.getId());
        } else if (path.startsWith(WsPaths.NOTIFICATIONS)) {
            Long userId = extractUserId(path);
            if (userId != null) {
                userSessions.computeIfAbsent(userId, k -> new ConcurrentHashMap<>())
                        .put(session.getId(), session);
                log.info("User notification WebSocket connected: userId={}, sessionId={}", userId, session.getId());
            } else {
                log.warn("Could not extract userId from notification path: {}", path);
            }
        } else if (path.startsWith(WsPaths.POSTS)) {
            Long postId = extractPostId(path);
            if (postId != null) {
                postSessions.computeIfAbsent(postId, k -> new ConcurrentHashMap<>())
                        .put(session.getId(), session);
                log.debug("Post WebSocket connected: postId={}, sessionId={}", postId, session.getId());
            } else {
                log.warn("Could not extract postId from path: {}", path);
            }
        } else {
            log.warn("WebSocket connected with unknown path: {}", path);
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String path = safePath(session);
        if (path == null) {
            return;
        }

        if (path.startsWith(WsPaths.ADMIN)) {
            adminSessions.remove(session.getId());
            log.info("Admin WebSocket disconnected: sessionId={}", session.getId());
        } else if (path.startsWith(WsPaths.NOTIFICATIONS)) {
            Long userId = extractUserId(path);
            if (userId != null) {
                removeSessionFromMap(userSessions, userId, session.getId());
                log.debug("User notification WebSocket disconnected: userId={}, sessionId={}", userId, session.getId());
            }
        } else if (path.startsWith(WsPaths.POSTS)) {
            Long postId = extractPostId(path);
            if (postId != null) {
                removeSessionFromMap(postSessions, postId, session.getId());
                log.debug("Post WebSocket disconnected: postId={}, sessionId={}", postId, session.getId());
            }
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
                log.debug("Failed to send pong to session={}", session.getId());
            }
        }
        // Other client-to-server messages can be handled here if needed.
    }

    // ── Broadcast API ─────────────────────────────────────────────────────

    /** Send a JSON-serialised message to every session watching a post. */
    public void sendToPost(Long postId, Object message) {
        Map<String, WebSocketSession> sessions = postSessions.get(postId);
        if (sessions != null && !sessions.isEmpty()) {
            broadcastToSessions(sessions.values(), message);
        }
    }

    /** Send a JSON-serialised message to every admin session. */
    public void sendToAdmins(Object message) {
        if (!adminSessions.isEmpty()) {
            broadcastToSessions(adminSessions.values(), message);
        }
    }

    /** Send a JSON-serialised message to every session owned by a user. */
    public void sendToUser(Long userId, Object message) {
        Map<String, WebSocketSession> sessions = userSessions.get(userId);
        if (sessions != null && !sessions.isEmpty()) {
            broadcastToSessions(sessions.values(), message);
        }
    }

    // ── Internal helpers ──────────────────────────────────────────────────

    /**
     * Serialise {@code message} to JSON once, then send to every open session.
     * Closed sessions are silently skipped (they will be cleaned up by the
     * scheduled heartbeat task).
     */
    private void broadcastToSessions(Collection<WebSocketSession> sessions, Object message) {
        String json;
        try {
            json = objectMapper.writeValueAsString(message);
        } catch (Exception e) {
            log.error("Failed to serialise WebSocket message: {}", e.getMessage(), e);
            return;
        }
        TextMessage textMessage = new TextMessage(json);
        for (WebSocketSession session : sessions) {
            try {
                if (session.isOpen()) {
                    session.sendMessage(textMessage);
                }
            } catch (IOException e) {
                log.debug("Failed to send to session={}: {}", session.getId(), e.getMessage());
            }
        }
    }

    /** Remove a single session from a nested map, cleaning empty inner maps. */
    private static <K> void removeSessionFromMap(Map<K, Map<String, WebSocketSession>> outer,
                                                  K key, String sessionId) {
        Map<String, WebSocketSession> inner = outer.get(key);
        if (inner != null) {
            inner.remove(sessionId);
            if (inner.isEmpty()) {
                outer.remove(key);
            }
        }
    }

    private static String safePath(WebSocketSession session) {
        URI uri = session.getUri();
        return uri != null ? uri.getPath() : null;
    }

    // ── Path extraction ───────────────────────────────────────────────────

    private static Long extractPostId(String path) {
        // /ws/posts/{postId}
        try {
            String[] parts = path.split("/");
            if (parts.length >= 4 && "posts".equals(parts[2])) {
                return Long.parseLong(parts[3]);
            }
        } catch (Exception ignored) {
            // malformed id — ignore
        }
        return null;
    }

    private static Long extractUserId(String path) {
        // /ws/notifications/{userId}
        try {
            String[] parts = path.split("/");
            if (parts.length >= 4 && "notifications".equals(parts[2])) {
                return Long.parseLong(parts[3]);
            }
        } catch (Exception ignored) {
            // malformed id — ignore
        }
        return null;
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

    // ── Heartbeat / zombie cleanup ────────────────────────────────────────

    /**
     * Every 60 seconds, remove sessions that have been idle for more than
     * {@link #SESSION_TTL_MS} (90 s).  This prevents stale sessions from
     * accumulating when clients disconnect without a proper close frame.
     */
    @Scheduled(fixedRate = 60_000)
    public void purgeZombieSessions() {
        Instant cutoff = Instant.now().minusMillis(SESSION_TTL_MS);
        purgeSessions(postSessions, cutoff);
        purgeAdminSessions(cutoff);
        purgeSessions(userSessions, cutoff);
    }

    private void purgeSessions(Map<Long, Map<String, WebSocketSession>> outer, Instant cutoff) {
        Iterator<Map.Entry<Long, Map<String, WebSocketSession>>> outerIt = outer.entrySet().iterator();
        while (outerIt.hasNext()) {
            Map.Entry<Long, Map<String, WebSocketSession>> entry = outerIt.next();
            Map<String, WebSocketSession> inner = entry.getValue();
            inner.values().removeIf(session -> isZombie(session, cutoff));
            if (inner.isEmpty()) {
                outerIt.remove();
            }
        }
    }

    private void purgeAdminSessions(Instant cutoff) {
        adminSessions.values().removeIf(session -> isZombie(session, cutoff));
    }

    private static boolean isZombie(WebSocketSession session, Instant cutoff) {
        try {
            if (!session.isOpen()) return true;
            // lastAccessTime is available from Spring 6.x / Boot 3.x
            long lastAccess = session.getAttributes().containsKey("lastAccessTime")
                    ? (Long) session.getAttributes().get("lastAccessTime")
                    : System.currentTimeMillis();
            return lastAccess < cutoff.toEpochMilli();
        } catch (Exception e) {
            return true; // if anything goes wrong, remove it
        }
    }
}
