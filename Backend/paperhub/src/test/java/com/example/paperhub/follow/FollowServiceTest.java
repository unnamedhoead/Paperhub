package com.example.paperhub.follow;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.notification.NotificationService;
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
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class FollowServiceTest {

    @Mock private UserFollowRepository followRepository;
    @Mock private UserRepository userRepository;
    @Mock private NotificationService notificationService;

    @InjectMocks
    private FollowService followService;

    private User follower;
    private User target;

    @BeforeEach
    void setUp() {
        follower = new User();
        follower.setId(1L);
        follower.setStatus(UserStatus.NORMAL);

        target = new User();
        target.setId(2L);
        target.setStatus(UserStatus.NORMAL);
    }

    @Test
    void followShouldCreateFollowRelationship() {
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(followRepository.existsByFollowerIdAndFollowingId(1L, 2L)).thenReturn(false);

        followService.follow(follower, 2L);

        verify(followRepository).save(any(UserFollow.class));
        verify(notificationService).createFollowNotification(follower, 2L);
    }

    @Test
    void followShouldNotCreateDuplicate() {
        when(userRepository.findById(2L)).thenReturn(Optional.of(target));
        when(followRepository.existsByFollowerIdAndFollowingId(1L, 2L)).thenReturn(true);

        followService.follow(follower, 2L);

        verify(followRepository, never()).save(any(UserFollow.class));
    }

    @Test
    void followShouldPreventSelfFollow() {
        assertThatThrownBy(() -> followService.follow(follower, 1L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("不能关注自己");
    }

    @Test
    void followShouldThrowWhenBanned() {
        follower.setStatus(UserStatus.BANNED);
        assertThatThrownBy(() -> followService.follow(follower, 2L))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("封禁");
    }

    @Test
    void unfollowShouldDeleteFollowRelationship() {
        followService.unfollow(follower, 2L);
        verify(followRepository).deleteByFollowerIdAndFollowingId(1L, 2L);
    }

    @Test
    void isFollowingShouldReturnFalseWhenNotFollowing() {
        when(followRepository.existsByFollowerIdAndFollowingId(1L, 2L)).thenReturn(false);
        boolean result = followService.isFollowing(1L, 2L);
        assertThat(result).isFalse();
    }

    @Test
    void isFollowingShouldReturnTrueWhenFollowing() {
        when(followRepository.existsByFollowerIdAndFollowingId(1L, 2L)).thenReturn(true);
        boolean result = followService.isFollowing(1L, 2L);
        assertThat(result).isTrue();
    }
}
