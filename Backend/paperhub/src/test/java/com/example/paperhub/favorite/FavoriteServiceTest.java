package com.example.paperhub.favorite;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.notification.NotificationService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.websocket.WebSocketService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FavoriteServiceTest {

    @Mock private FavoritePostRepository favoriteRepository;
    @Mock private PostRepository postRepository;
    @Mock private NotificationService notificationService;
    @Mock private WebSocketService webSocketService;

    @InjectMocks
    private FavoriteService favoriteService;

    private User user;
    private Post post;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(1L);
        user.setStatus(UserStatus.NORMAL);

        post = new Post();
        post.setId(10L);
        post.setFavoriteCount(3);
    }

    @Test
    void favoritePostShouldCreateAndIncrement() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(favoriteRepository.existsByUserIdAndPostId(1L, 10L)).thenReturn(false);
        when(favoriteRepository.countByPostId(10L)).thenReturn(4L);

        favoriteService.favoritePost(10L, user);

        verify(favoriteRepository).save(any(FavoritePost.class));
        verify(favoriteRepository).incrementFavoriteCount(10L, 1);
        verify(webSocketService).sendPostFavoriteUpdate(eq(10L), eq(4), eq(true));
        verify(notificationService).createPostFavoriteNotification(user, 10L);
    }

    @Test
    void favoritePostShouldBeIdempotent() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(favoriteRepository.existsByUserIdAndPostId(1L, 10L)).thenReturn(true);

        favoriteService.favoritePost(10L, user);

        // Should NOT create duplicate
        verify(favoriteRepository, never()).save(any(FavoritePost.class));
        verify(favoriteRepository, never()).incrementFavoriteCount(anyLong(), anyInt());
    }

    @Test
    void unfavoritePostShouldDeleteAndDecrement() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(favoriteRepository.existsByUserIdAndPostId(1L, 10L)).thenReturn(true);
        when(favoriteRepository.countByPostId(10L)).thenReturn(2L);

        favoriteService.unfavoritePost(10L, user);

        verify(favoriteRepository).deleteByUserIdAndPostId(1L, 10L);
        verify(favoriteRepository).incrementFavoriteCount(10L, -1);
        verify(webSocketService).sendPostFavoriteUpdate(eq(10L), eq(2), eq(false));
        // No notification on unfavorite
        verify(notificationService, never()).createPostFavoriteNotification(any(), anyLong());
    }

    @Test
    void unfavoritePostShouldBeIdempotentWhenNotFavorited() {
        when(postRepository.findById(10L)).thenReturn(Optional.of(post));
        when(favoriteRepository.existsByUserIdAndPostId(1L, 10L)).thenReturn(false);

        favoriteService.unfavoritePost(10L, user);

        verify(favoriteRepository, never()).deleteByUserIdAndPostId(anyLong(), anyLong());
    }

    @Test
    void isFavoriteShouldReturnFalseForNullUser() {
        assertThat(favoriteService.isFavorite(10L, null)).isFalse();
    }

    @Test
    void isFavoriteShouldReturnTrue() {
        when(favoriteRepository.existsByUserIdAndPostId(1L, 10L)).thenReturn(true);
        assertThat(favoriteService.isFavorite(10L, 1L)).isTrue();
    }

    @Test
    void ensureUserCanInteractShouldThrowWhenBanned() {
        user.setStatus(UserStatus.BANNED);
        assertThatThrownBy(() -> favoriteService.favoritePost(10L, user))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("封禁");
    }
}
