package com.example.paperhub.notification;

import com.example.paperhub.websocket.WebSocketService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

/**
 * 负责通知相关的 WebSocket 推送，与通知业务逻辑解耦。
 */
@Service
public class NotificationPushService {

    private static final Logger log = LoggerFactory.getLogger(NotificationPushService.class);
    private final WebSocketService webSocketService;

    public NotificationPushService(WebSocketService webSocketService) {
        this.webSocketService = webSocketService;
    }

    /**
     * 推送新通知到指定用户，同时更新未读计数。
     */
    public void pushNotification(Long recipientId, Notification notification) {
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("id", notification.getId());
            data.put("type", notification.getType().name());
            data.put("actorId", notification.getActor().getId());
            data.put("actorName", notification.getActor().getName());
            data.put("createdAt", notification.getCreatedAt().toString());

            if (notification.getPost() != null) {
                data.put("postId", notification.getPost().getId());
                data.put("postTitle", notification.getPost().getTitle());
            }
            if (notification.getComment() != null) {
                data.put("commentId", notification.getComment().getId());
                data.put("commentContent", notification.getComment().getContent());
            }

            webSocketService.sendNewNotification(recipientId, notification.getType().name(), data);
        } catch (Exception e) {
            log.warn("WebSocket 推送通知失败, recipientId={}", recipientId, e);
        }
    }

    /**
     * 推送未读计数更新。
     */
    public void pushUnreadCounts(Long userId, Map<String, Long> unreadCounts) {
        try {
            Map<String, Integer> counts = new HashMap<>();
            unreadCounts.forEach((key, value) -> counts.put(key, value.intValue()));
            webSocketService.sendUnreadCountUpdate(userId, counts);
        } catch (Exception e) {
            log.warn("WebSocket 推送未读计数失败, userId={}", userId, e);
        }
    }
}
