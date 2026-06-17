package com.example.paperhub.websocket;

import com.example.paperhub.comment.dto.CommentDtos;
import com.example.paperhub.websocket.message.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * WebSocket service — central entry point for server-to-client push.
 * <p>
 * Other modules (P3 post, P4 notification/interaction, P6 admin) call the
 * {@code pushTo*()} methods exposed here.  Do NOT add new inner message
 * classes — put them in {@code websocket/message/} as independent POJOs.
 * </p>
 */
@Service
public class WebSocketService {

    private static final Logger log = LoggerFactory.getLogger(WebSocketService.class);

    private final SimpleWebSocketHandler webSocketHandler;

    public WebSocketService(SimpleWebSocketHandler webSocketHandler) {
        this.webSocketHandler = webSocketHandler;
    }

    // ── Public push API (for P3/P4/P6) ────────────────────────────────────

    /** Push an arbitrary object to all sessions watching a given post. */
    public void pushToPost(Long postId, Object message) {
        webSocketHandler.sendToPost(postId, message);
    }

    /** Push an arbitrary object to all admin sessions. */
    public void pushToAdmins(Object message) {
        webSocketHandler.sendToAdmins(message);
    }

    /** Push an arbitrary object to all sessions of a given user. */
    public void pushToUser(Long userId, Object message) {
        webSocketHandler.sendToUser(userId, message);
    }

    // ── Convenience methods (keep existing call sites working) ────────────

    /** Push a post like-count update. */
    public void sendPostLikeUpdate(Long postId, int likesCount, boolean isLiked) {
        pushToPost(postId, new LikeUpdateMessage("like_update", likesCount, isLiked, null, null));
    }

    /** Push a post favourite-count update. */
    public void sendPostFavoriteUpdate(Long postId, int favoriteCount, boolean isSaved) {
        pushToPost(postId, new FavoriteUpdateMessage("favorite_update", favoriteCount, isSaved));
    }

    /** Push a comment like-count update. */
    public void sendCommentLikeUpdate(Long postId, String commentId, int likesCount, boolean isLiked) {
        pushToPost(postId, new CommentLikeUpdateMessage("comment_like_update", commentId, likesCount, isLiked));
    }

    /** Push a newly-created comment. */
    public void sendCommentCreated(Long postId, CommentDtos.CommentResp comment) {
        pushToPost(postId, new CommentCreatedMessage("comment_created", comment));
    }

    /** Push an updated comment. */
    public void sendCommentUpdated(Long postId, CommentDtos.CommentResp comment) {
        pushToPost(postId, new CommentUpdatedMessage("comment_updated", comment));
    }

    /** Push a deleted comment id. */
    public void sendCommentDeleted(Long postId, String commentId) {
        pushToPost(postId, new CommentDeletedMessage("comment_deleted", commentId));
    }

    /** Push a post status change (admin broadcast). */
    public void sendPostStatusUpdate(Long postId, String status, String title) {
        pushToAdmins(new PostStatusUpdateMessage("post_status_update", postId, status, title));
    }

    /** Push a new notification to a user. */
    public void sendNewNotification(Long userId, String notificationType, Map<String, Object> data) {
        pushToUser(userId, new NotificationMessage("new_notification", notificationType, data));
    }

    /** Push unread-count summary to a user. */
    public void sendUnreadCountUpdate(Long userId, Map<String, Integer> unreadCounts) {
        pushToUser(userId, new UnreadCountUpdateMessage("unread_count_update", unreadCounts));
    }
}
