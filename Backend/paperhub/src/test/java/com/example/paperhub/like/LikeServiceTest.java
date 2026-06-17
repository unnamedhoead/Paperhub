package com.example.paperhub.like;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.comment.Comment;
import com.example.paperhub.comment.CommentRepository;
import com.example.paperhub.notification.NotificationService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LikeServiceTest {

    @Mock private PostLikeRepository postLikeRepository;
    @Mock private CommentLikeRepository commentLikeRepository;
    @Mock private PostRepository postRepository;
    @Mock private CommentRepository commentRepository;
    @Mock private PostService postService;
    @Mock private NotificationService notificationService;

    @InjectMocks
    private LikeService likeService;

    private User user;
    private Post post;
    private Comment comment;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setStatus(UserStatus.NORMAL);

        post = new Post();
        post.setId(10L);
        post.setLikesCount(5);

        comment = new Comment();
        comment.setId(100L);
        comment.setLikesCount(3);
    }

    // --- Post Like Tests ---

    @Test
    void likePostShouldCreateLikeAndIncrementCounter() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(postLikeRepository.findByPostAndUser(post, user)).thenReturn(Optional.empty());

        boolean result = likeService.likePost(10L, user);

        assertThat(result).isTrue();
        verify(postLikeRepository).save(any(PostLike.class));
        verify(postLikeRepository).incrementPostLikesCount(10L, 1);
        verify(notificationService).createPostLikeNotification(user, 10L);
    }

    @Test
    void likePostShouldBeIdempotent() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        PostLike existing = new PostLike();
        when(postLikeRepository.findByPostAndUser(post, user)).thenReturn(Optional.of(existing));

        boolean result = likeService.likePost(10L, user);

        assertThat(result).isTrue();
        // Should NOT create duplicate or increment
        verify(postLikeRepository, never()).save(any(PostLike.class));
        verify(postLikeRepository, never()).incrementPostLikesCount(anyLong(), anyInt());
    }

    @Test
    void unlikePostShouldDeleteLikeAndDecrementCounter() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        PostLike existing = new PostLike();
        when(postLikeRepository.findByPostAndUser(post, user)).thenReturn(Optional.of(existing));

        boolean result = likeService.unlikePost(10L, user);

        assertThat(result).isTrue();
        verify(postLikeRepository).delete(existing);
        verify(postLikeRepository).incrementPostLikesCount(10L, -1);
    }

    @Test
    void unlikePostShouldBeIdempotentWhenNotLiked() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(postLikeRepository.findByPostAndUser(post, user)).thenReturn(Optional.empty());

        boolean result = likeService.unlikePost(10L, user);

        assertThat(result).isTrue();
        verify(postLikeRepository, never()).delete(any());
        verify(postLikeRepository, never()).incrementPostLikesCount(anyLong(), anyInt());
    }

    // --- Comment Like Tests ---

    @Test
    void likeCommentShouldCreateLikeAndIncrementCounter() {
        when(commentRepository.findById(100L)).thenReturn(Optional.of(comment));
        when(commentLikeRepository.findByCommentAndUser(comment, user)).thenReturn(Optional.empty());

        boolean result = likeService.likeComment(100L, user);

        assertThat(result).isTrue();
        verify(commentLikeRepository).save(any(CommentLike.class));
        verify(commentLikeRepository).incrementCommentLikesCount(100L, 1);
        verify(notificationService).createCommentLikeNotification(user, 100L);
    }

    @Test
    void likeCommentShouldBeIdempotent() {
        when(commentRepository.findById(100L)).thenReturn(Optional.of(comment));
        CommentLike existing = new CommentLike();
        when(commentLikeRepository.findByCommentAndUser(comment, user)).thenReturn(Optional.of(existing));

        boolean result = likeService.likeComment(100L, user);

        assertThat(result).isTrue();
        verify(commentLikeRepository, never()).save(any(CommentLike.class));
    }

    @Test
    void unlikeCommentShouldDeleteLikeAndDecrementCounter() {
        when(commentRepository.findById(100L)).thenReturn(Optional.of(comment));
        CommentLike existing = new CommentLike();
        when(commentLikeRepository.findByCommentAndUser(comment, user)).thenReturn(Optional.of(existing));

        boolean result = likeService.unlikeComment(100L, user);

        assertThat(result).isTrue();
        verify(commentLikeRepository).delete(existing);
        verify(commentLikeRepository).incrementCommentLikesCount(100L, -1);
    }

    // --- isLiked tests ---

    @Test
    void isPostLikedShouldReturnTrue() {
        when(postLikeRepository.existsByPostIdAndUserId(10L, 1L)).thenReturn(true);
        assertThat(likeService.isPostLiked(10L, 1L)).isTrue();
    }

    @Test
    void isCommentLikedShouldReturnFalse() {
        when(commentLikeRepository.existsByCommentIdAndUserId(100L, 1L)).thenReturn(false);
        assertThat(likeService.isCommentLiked(100L, 1L)).isFalse();
    }

    // --- getLikesCount: no longer swallows exceptions ---

    @Test
    void getPostLikesCountShouldReturnCount() {
        when(postLikeRepository.countByPostId(10L)).thenReturn(7L);
        long count = likeService.getPostLikesCount(10L);
        assertThat(count).isEqualTo(7L);
        verify(postLikeRepository).setPostLikesCount(10L, 7);
    }

    @Test
    void getPostLikesCountShouldThrowOnError() {
        when(postLikeRepository.countByPostId(10L)).thenThrow(new RuntimeException("DB error"));
        assertThatThrownBy(() -> likeService.getPostLikesCount(10L))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("获取帖子点赞数失败");
    }

    @Test
    void getCommentLikesCountShouldThrowOnError() {
        when(commentLikeRepository.countByCommentId(100L)).thenThrow(new RuntimeException("DB error"));
        assertThatThrownBy(() -> likeService.getCommentLikesCount(100L))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("获取评论点赞数失败");
    }

    // --- Banned user cannot interact ---

    @Test
    void likePostShouldThrowWhenBanned() {
        user.setStatus(UserStatus.BANNED);
        assertThatThrownBy(() -> likeService.likePost(10L, user))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("封禁");
    }
}
