package com.example.paperhub.user;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.favorite.FavoritePostRepository;
import com.example.paperhub.follow.UserFollowRepository;
import com.example.paperhub.like.PostLikeRepository;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.user.dto.ProfileResp;
import com.example.paperhub.user.dto.PrivacySettingsResp;
import com.example.paperhub.user.dto.UpdatePrivacySettingsReq;
import com.example.paperhub.user.dto.UpdateProfileReq;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private UserFollowRepository followRepository;
    @Mock
    private FavoritePostRepository favoriteRepository;
    @Mock
    private PostLikeRepository postLikeRepository;
    @Mock
    private PostRepository postRepository;

    private UserService userService;

    @BeforeEach
    void setUp() {
        userService = new UserService(
                userRepository, followRepository, favoriteRepository,
                postLikeRepository, postRepository);
    }

    private User createUser(Long id, String name, String email) {
        User user = new User();
        user.setId(id);
        user.setName(name);
        user.setEmail(email);
        return user;
    }

    // ── toProfile ──

    @Test
    void toProfileShouldMapBasicFields() {
        User user = createUser(1L, "Alice", "alice@example.com");
        user.setBio("Hello");
        user.setResearchDirections("AI,ML");

        when(followRepository.countByFollowerId(1L)).thenReturn(10L);
        when(followRepository.countByFollowingId(1L)).thenReturn(5L);
        when(favoriteRepository.countByUserId(1L)).thenReturn(3L);
        when(favoriteRepository.countByPostAuthorId(1L)).thenReturn(8L);
        when(postRepository.countByAuthorId(1L)).thenReturn(4L);
        when(postLikeRepository.countByAuthorId(1L)).thenReturn(20L);

        ProfileResp profile = userService.toProfile(user);

        assertEquals(1L, profile.id());
        assertEquals("alice@example.com", profile.email());
        assertEquals("Alice", profile.displayName());
        assertEquals("Hello", profile.bio());
        assertEquals(List.of("AI", "ML"), profile.researchDirections());
        assertEquals(10, profile.followingCount());
        assertEquals(5, profile.followersCount());
        assertEquals(4, profile.postsCount());
        assertEquals(3, profile.favoritesCount());
        assertEquals(8, profile.favoritesReceivedCount());
        assertEquals(20, profile.likesCount());
        assertEquals("USER", profile.role());
        assertEquals("NORMAL", profile.status());
    }

    @Test
    void toProfileShouldSetIsFollowingWhenViewerFollowsTarget() {
        User target = createUser(2L, "Bob", "bob@example.com");
        User viewer = createUser(1L, "Alice", "alice@example.com");

        when(followRepository.countByFollowerId(anyLong())).thenReturn(0L);
        when(followRepository.countByFollowingId(anyLong())).thenReturn(0L);
        when(favoriteRepository.countByUserId(anyLong())).thenReturn(0L);
        when(favoriteRepository.countByPostAuthorId(anyLong())).thenReturn(0L);
        when(postRepository.countByAuthorId(anyLong())).thenReturn(0L);
        when(postLikeRepository.countByAuthorId(anyLong())).thenReturn(0L);
        when(followRepository.existsByFollowerIdAndFollowingId(1L, 2L)).thenReturn(true);
        when(followRepository.existsByFollowerIdAndFollowingId(2L, 1L)).thenReturn(false);

        ProfileResp profile = userService.toProfile(target, viewer);

        assertTrue(profile.isFollowing());
        assertFalse(profile.isFollower());
    }

    @Test
    void toProfileShouldShowBannedStatusMessage() {
        User user = createUser(1L, "Bad", "bad@example.com");
        user.setStatus(UserStatus.BANNED);

        when(followRepository.countByFollowerId(anyLong())).thenReturn(0L);
        when(followRepository.countByFollowingId(anyLong())).thenReturn(0L);
        when(favoriteRepository.countByUserId(anyLong())).thenReturn(0L);
        when(favoriteRepository.countByPostAuthorId(anyLong())).thenReturn(0L);
        when(postRepository.countByAuthorId(anyLong())).thenReturn(0L);
        when(postLikeRepository.countByAuthorId(anyLong())).thenReturn(0L);

        ProfileResp profile = userService.toProfile(user);

        assertEquals("BANNED", profile.status());
        assertEquals("该用户被封禁中", profile.statusMessage());
    }

    @Test
    void toProfileShouldUseEmailPrefixAsDisplayNameWhenNameIsNull() {
        User user = createUser(1L, null, "charlie@example.com");

        when(followRepository.countByFollowerId(anyLong())).thenReturn(0L);
        when(followRepository.countByFollowingId(anyLong())).thenReturn(0L);
        when(favoriteRepository.countByUserId(anyLong())).thenReturn(0L);
        when(favoriteRepository.countByPostAuthorId(anyLong())).thenReturn(0L);
        when(postRepository.countByAuthorId(anyLong())).thenReturn(0L);
        when(postLikeRepository.countByAuthorId(anyLong())).thenReturn(0L);

        ProfileResp profile = userService.toProfile(user);

        assertEquals("charlie", profile.displayName());
    }

    // ── updateProfile ──

    @Test
    void updateProfileShouldUpdateFieldsAndSave() {
        User user = createUser(1L, "Old", "old@example.com");
        UpdateProfileReq req = new UpdateProfileReq("New", "NewBio",
                List.of("AI", "DL"), "bg.jpg");

        when(userRepository.save(user)).thenReturn(user);

        User result = userService.updateProfile(user, req);

        assertEquals("New", result.getName());
        assertEquals("NewBio", result.getBio());
        assertEquals("AI,DL", result.getResearchDirections());
        assertEquals("bg.jpg", result.getProfileBackground());
        verify(userRepository).save(user);
    }

    // ── getUserById ──

    @Test
    void getUserByIdShouldReturnUserWhenFound() {
        User user = createUser(1L, "Alice", "alice@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        User result = userService.getUserById(1L);
        assertSame(user, result);
    }

    @Test
    void getUserByIdShouldThrowWhenNotFound() {
        when(userRepository.findById(999L)).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class,
                () -> userService.getUserById(999L));
    }

    // ── updatePrivacy ──

    @Test
    void updatePrivacyShouldUpdateAllThreeFlags() {
        User user = createUser(1L, "A", "a@b.com");
        UpdatePrivacySettingsReq req = new UpdatePrivacySettingsReq(
                true, true, false);

        PrivacySettingsResp resp = userService.updatePrivacy(user, req);

        assertTrue(user.isHideFollowing());
        assertTrue(user.isHideFollowers());
        assertFalse(user.isPublicFavorites());
        assertTrue(resp.hideFollowing());
        assertTrue(resp.hideFollowers());
        assertFalse(resp.publicFavorites());
        verify(userRepository).save(user);
    }

    @Test
    void updatePrivacyShouldNotChangeNullFields() {
        User user = createUser(1L, "A", "a@b.com");
        user.setHideFollowing(false);
        user.setHideFollowers(false);
        user.setPublicFavorites(true);

        // Only update hideFollowing, leave others unchanged
        UpdatePrivacySettingsReq req = new UpdatePrivacySettingsReq(
                true, null, null);

        userService.updatePrivacy(user, req);

        assertTrue(user.isHideFollowing());
        assertFalse(user.isHideFollowers());
        assertTrue(user.isPublicFavorites());
    }

    // ── searchByName ──

    @Test
    void searchByNameShouldDelegateToRepository() {
        User alice = createUser(1L, "Alice", "alice@example.com");
        when(userRepository.findByNameContainingIgnoreCase("Ali"))
                .thenReturn(List.of(alice));

        List<User> result = userService.searchByName("Ali");
        assertEquals(1, result.size());
        assertEquals("Alice", result.get(0).getName());
    }

    // ── refreshUser ──

    @Test
    void refreshUserShouldReturnUserWhenFound() {
        User user = createUser(1L, "Alice", "alice@example.com");
        when(userRepository.findById(1L)).thenReturn(Optional.of(user));

        User result = userService.refreshUser(1L);
        assertSame(user, result);
    }

    @Test
    void refreshUserShouldThrowWhenNotFound() {
        when(userRepository.findById(999L)).thenReturn(Optional.empty());

        assertThrows(IllegalStateException.class,
                () -> userService.refreshUser(999L));
    }
}
