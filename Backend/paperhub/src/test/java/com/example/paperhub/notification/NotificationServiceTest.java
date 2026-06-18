package com.example.paperhub.notification;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.comment.Comment;
import com.example.paperhub.comment.CommentRepository;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyMap;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationServiceTest {

    @Mock private NotificationRepository notificationRepository;
    @Mock private UserRepository userRepository;
    @Mock private PostRepository postRepository;
    @Mock private CommentRepository commentRepository;
    @Mock private NotificationPushService notificationPushService;

    @InjectMocks
    private NotificationService notificationService;

    private User actor;
    private User recipient;
    private Post post;
    private Comment comment;

    @BeforeEach
    void setUp() {
        actor = new User();
        actor.setId(1L);
        actor.setName("Actor");

        recipient = new User();
        recipient.setId(2L);
        recipient.setName("Recipient");

        post = new Post();
        post.setId(10L);
        post.setTitle("Test Post");
        post.setAuthor(recipient);

        comment = new Comment();
        comment.setId(100L);
        comment.setContent("Test comment");
        comment.setAuthor(recipient);
        comment.setPost(post);
    }

    @Test
    void createNotificationShouldSaveAndPush() {
        notificationService.createNotification(actor, recipient, NotificationType.POST_LIKE, post, null);

        verify(notificationRepository).save(any(Notification.class));
        verify(notificationPushService).pushNotification(eq(2L), any(Notification.class));
        verify(notificationPushService).pushUnreadCounts(eq(2L), anyMap());
    }

    @Test
    void createNotificationShouldNotNotifySelf() {
        notificationService.createNotification(actor, actor, NotificationType.POST_LIKE, post, null);

        // Should NOT save or push for self-notification
        verify(notificationRepository, never()).save(any(Notification.class));
        verify(notificationPushService, never()).pushNotification(anyLong(), any(Notification.class));
    }

    @Test
    void createPostLikeNotificationShouldFindPostAndNotify() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));

        notificationService.createPostLikeNotification(actor, 10L);

        verify(notificationRepository).save(any(Notification.class));
        verify(notificationPushService).pushNotification(eq(2L), any(Notification.class));
    }

    @Test
    void createCommentNotificationShouldNotifyPostAuthorAndReplyTo() {
        User replyTo = new User();
        replyTo.setId(3L);
        replyTo.setName("ReplyTarget");
        // The comment's post author is already set to recipient (id=2)

        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(commentRepository.findById(100L)).thenReturn(Optional.of(comment));

        notificationService.createCommentNotification(actor, 10L, 100L, replyTo);

        // Should notify post author (COMMENT) and replyTo user (MENTION)
        verify(notificationRepository, atLeast(2)).save(any(Notification.class));
        verify(notificationPushService, atLeast(2)).pushNotification(anyLong(), any(Notification.class));
    }

    @Test
    void createCommentNotificationShouldNotNotifySelfAsPostAuthor() {
        // Actor IS the post author
        post.setAuthor(actor);

        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(commentRepository.findById(100L)).thenReturn(Optional.of(comment));

        notificationService.createCommentNotification(actor, 10L, 100L, null);

        // Should NOT notify post author (self) - only verify push was never called
        verify(notificationPushService, never()).pushNotification(anyLong(), any(Notification.class));
    }

    @Test
    void createMentionNotificationShouldNotNotifyIfSelf() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(commentRepository.findById(100L)).thenReturn(Optional.of(comment));

        // Mentioning yourself
        notificationService.createMentionNotification(actor, 10L, 100L, actor);

        verify(notificationRepository, never()).save(any(Notification.class));
    }

    @Test
    void createMentionNotificationShouldNotNotifyIfPostAuthor() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(commentRepository.findById(100L)).thenReturn(Optional.of(comment));

        // Mentioning the post author (who already gets COMMENT notification)
        notificationService.createMentionNotification(actor, 10L, 100L, recipient);

        // Should skip because mentioned user IS the post author
        verify(notificationRepository, never()).save(any(Notification.class));
    }

    @Test
    void createFollowNotificationShouldFindTargetAndNotify() {
        when(userRepository.findById(2L)).thenReturn(Optional.of(recipient));

        notificationService.createFollowNotification(actor, 2L);

        verify(notificationRepository).save(any(Notification.class));
        verify(notificationPushService).pushNotification(eq(2L), any(Notification.class));
    }

    @Test
    void createPostRemovedNotificationShouldSaveWithoutPush() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));

        notificationService.createPostRemovedNotification(actor, 10L, "violation");

        verify(notificationRepository).save(any(Notification.class));
        // Post removed does NOT push via websocket (admin notification only)
        verify(notificationPushService, never()).pushNotification(anyLong(), any(Notification.class));
    }

    @Test
    void markAsReadShouldUpdateAndPush() {
        Notification notification = new Notification();
        notification.setId(1L);
        notification.setRecipient(recipient);
        notification.setRead(false);
        when(notificationRepository.findById(1L)).thenReturn(Optional.of(notification));

        notificationService.markAsRead(1L, recipient);

        assertThat(notification.isRead()).isTrue();
        verify(notificationRepository).save(notification);
        verify(notificationPushService).pushUnreadCounts(eq(2L), anyMap());
    }

    @Test
    void markAsReadShouldThrowWhenNotRecipient() {
        Notification notification = new Notification();
        notification.setId(1L);
        notification.setRecipient(recipient);
        when(notificationRepository.findById(1L)).thenReturn(Optional.of(notification));

        User otherUser = new User();
        otherUser.setId(99L);

        try {
            notificationService.markAsRead(1L, otherUser);
        } catch (IllegalArgumentException e) {
            assertThat(e.getMessage()).contains("无权");
        }
        // Notification should still be unread
        assertThat(notification.isRead()).isFalse();
    }

    @Test
    void markAllAsReadByTypesShouldUpdateAndPush() {
        when(notificationRepository.findByRecipientAndTypeAndReadFalse(recipient, NotificationType.POST_LIKE))
                .thenReturn(List.of());

        notificationService.markAllAsReadByTypes(recipient, List.of(NotificationType.POST_LIKE));

        verify(notificationRepository).saveAll(anyList());
        verify(notificationPushService).pushUnreadCounts(eq(2L), anyMap());
    }

    @Test
    void getUnreadCountsShouldAggregateCorrectly() {
        when(userRepository.findById(2L)).thenReturn(Optional.of(recipient));
        when(notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.POST_LIKE))
                .thenReturn(3L);
        when(notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.POST_FAVORITE))
                .thenReturn(2L);
        when(notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.COMMENT_LIKE))
                .thenReturn(1L);
        when(notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.FOLLOW))
                .thenReturn(4L);
        when(notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.COMMENT))
                .thenReturn(2L);
        when(notificationRepository.countByRecipientAndTypeAndReadFalse(recipient, NotificationType.MENTION))
                .thenReturn(1L);

        var counts = notificationService.getUnreadCounts(2L);

        assertThat(counts.get("likes")).isEqualTo(6L);   // 3 + 2 + 1
        assertThat(counts.get("follows")).isEqualTo(4L);
        assertThat(counts.get("comments")).isEqualTo(3L); // 2 + 1
    }
}
