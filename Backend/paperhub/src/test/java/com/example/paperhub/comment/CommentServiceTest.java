package com.example.paperhub.comment;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.like.CommentLikeRepository;
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

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CommentServiceTest {

    @Mock private CommentRepository commentRepository;
    @Mock private PostRepository postRepository;
    @Mock private UserRepository userRepository;
    @Mock private PostService postService;
    @Mock private NotificationService notificationService;
    @Mock private CommentLikeRepository commentLikeRepository;

    @InjectMocks
    private CommentService commentService;

    private User author;
    private User otherUser;
    private Post post;
    private Comment topLevelComment;
    private Comment childComment;

    @BeforeEach
    void setUp() {
        author = new User();
        author.setId(1L);
        author.setStatus(UserStatus.NORMAL);

        otherUser = new User();
        otherUser.setId(2L);
        otherUser.setStatus(UserStatus.NORMAL);

        post = new Post();
        post.setId(10L);
        post.setAuthor(author);
        post.setCommentsCount(5);

        topLevelComment = new Comment();
        topLevelComment.setId(100L);
        topLevelComment.setPost(post);
        topLevelComment.setAuthor(author);
        topLevelComment.setContent("top-level");
        topLevelComment.setParent(null);

        childComment = new Comment();
        childComment.setId(101L);
        childComment.setPost(post);
        childComment.setAuthor(otherUser);
        childComment.setContent("child reply");
        childComment.setParent(topLevelComment);
    }

    @Test
    void deleteTopLevelCommentShouldBatchDeleteDescendants() {
        when(commentRepository.findById(100L)).thenReturn(Optional.of(topLevelComment));
        // Return one child reply
        when(commentRepository.findByParentIdOrderByCreatedAtAsc(100L)).thenReturn(List.of(childComment));
        // No grandchildren
        when(commentRepository.findByParentIdOrderByCreatedAtAsc(101L)).thenReturn(List.of());

        commentService.deleteComment(100L, author);

        // Should batch-delete likes for [100, 101]
        verify(commentLikeRepository).deleteByCommentIdIn(argThat(list ->
                list.containsAll(List.of(100L, 101L)) && list.size() == 2));
        // Should batch-delete comments for [100, 101]
        verify(commentRepository).deleteAllByIdIn(argThat(list ->
                list.containsAll(List.of(100L, 101L)) && list.size() == 2));
        // Should decrement post comment count by 2
        verify(commentRepository).decrementPostCommentsCount(10L, 2);
    }

    @Test
    void deleteChildCommentShouldSingleDelete() {
        when(commentRepository.findById(101L)).thenReturn(Optional.of(childComment));
        // childComment's author is otherUser, but post author is author -
        // post author can delete any comment on their post
        commentService.deleteComment(101L, author);

        verify(commentLikeRepository).deleteByCommentIdIn(List.of(101L));
        verify(commentRepository).deleteById(101L);
        verify(commentRepository).decrementPostCommentsCount(10L, 1);
    }

    @Test
    void deleteCommentShouldThrowWhenNoPermission() {
        when(commentRepository.findById(101L)).thenReturn(Optional.of(childComment));
        User randomUser = new User();
        randomUser.setId(99L);

        assertThatThrownBy(() -> commentService.deleteComment(101L, randomUser))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("无权");
    }

    @Test
    void deleteTopLevelCommentWithNestedRepliesShouldCollectAll() {
        // Setup: topLevel -> child1 -> grandchild
        Comment child1 = new Comment();
        child1.setId(101L);
        child1.setParent(topLevelComment);
        child1.setPost(post);
        child1.setAuthor(otherUser);

        Comment grandchild = new Comment();
        grandchild.setId(102L);
        grandchild.setParent(child1);
        grandchild.setPost(post);
        grandchild.setAuthor(otherUser);

        when(commentRepository.findById(100L)).thenReturn(Optional.of(topLevelComment));
        when(commentRepository.findByParentIdOrderByCreatedAtAsc(100L)).thenReturn(List.of(child1));
        when(commentRepository.findByParentIdOrderByCreatedAtAsc(101L)).thenReturn(List.of(grandchild));
        when(commentRepository.findByParentIdOrderByCreatedAtAsc(102L)).thenReturn(List.of());

        commentService.deleteComment(100L, author);

        // Should collect all 3 IDs: [100, 101, 102]
        verify(commentLikeRepository).deleteByCommentIdIn(argThat(list -> list.size() == 3));
        verify(commentRepository).deleteAllByIdIn(argThat(list -> list.size() == 3));
        verify(commentRepository).decrementPostCommentsCount(10L, 3);
    }

    @Test
    void ensureUserCanInteractShouldThrowWhenNull() {
        assertThatThrownBy(() -> commentService.createComment(10L, "test", null, null, null, List.of()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("未认证");
    }

    @Test
    void ensureUserCanInteractShouldThrowWhenBanned() {
        author.setStatus(UserStatus.BANNED);
        assertThatThrownBy(() -> commentService.createComment(10L, "test", author, null, null, List.of()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("封禁");
    }
}
