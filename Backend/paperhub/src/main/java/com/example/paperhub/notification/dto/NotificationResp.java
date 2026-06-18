package com.example.paperhub.notification.dto;

import com.example.paperhub.notification.Notification;
import com.example.paperhub.notification.NotificationType;

public record NotificationResp(
        Long id,
        ActorInfo actor,
        NotificationType type,
        String content,
        PostInfo post,
        CommentInfo comment,
        boolean read,
        String createdAt
) {
    public static NotificationResp from(Notification notification) {
        String content = generateContent(notification);
        return new NotificationResp(
                notification.getId(),
                new ActorInfo(
                        notification.getActor().getId(),
                        notification.getActor().getName() != null ? notification.getActor().getName() : notification.getActor().getEmail(),
                        notification.getActor().getAvatar()
                ),
                notification.getType(),
                content,
                notification.getPost() != null ? new PostInfo(
                        notification.getPost().getId(),
                        notification.getPost().getTitle()
                ) : null,
                notification.getComment() != null ? new CommentInfo(
                        notification.getComment().getId(),
                        notification.getComment().getContent()
                ) : null,
                notification.isRead(),
                notification.getCreatedAt().toString()
        );
    }

    private static String generateContent(Notification notification) {
        String actorName = notification.getActor().getName() != null
                ? notification.getActor().getName()
                : notification.getActor().getEmail();

        switch (notification.getType()) {
            case POST_LIKE:
                return actorName + "赞了你的笔记《" +
                       (notification.getPost() != null ? notification.getPost().getTitle() : "") + "》";
            case POST_FAVORITE:
                return actorName + "收藏了你的笔记《" +
                       (notification.getPost() != null ? notification.getPost().getTitle() : "") + "》";
            case COMMENT_LIKE:
                return actorName + "赞了你的评论";
            case COMMENT:
                return actorName + "评论了你的笔记《" +
                       (notification.getPost() != null ? notification.getPost().getTitle() : "") + "》";
            case MENTION:
                return actorName + "在《" +
                       (notification.getPost() != null ? notification.getPost().getTitle() : "") +
                       "》中@了你";
            case FOLLOW:
                return actorName + "关注了你";
            default:
                return "";
        }
    }
}
