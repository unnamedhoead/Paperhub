package com.example.paperhub.follow;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.user.UserService;
import com.example.paperhub.user.dto.UserListResp;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Follow/unfollow + following/followers/mutual list endpoints.
 * All paths under /users to preserve backward compatibility with the Flutter frontend
 * which calls /users/{userId}/follow, /users/{userId}/following, etc.
 */
@RestController
@RequestMapping("/users")
public class FollowController {

    private static final Logger log = LoggerFactory.getLogger(FollowController.class);
    private final FollowService followService;
    private final UserService userService;
    private final UserRepository userRepository;

    public FollowController(FollowService followService, UserService userService, UserRepository userRepository) {
        this.followService = followService;
        this.userService = userService;
        this.userRepository = userRepository;
    }

    @PostMapping("/{userId}/follow")
    public ResponseEntity<Map<String, Boolean>> followUser(
            @AuthenticationPrincipal User currentUser,
            @PathVariable Long userId) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        log.info("User {} following user {}", currentUser.getId(), userId);
        followService.follow(currentUser, userId);
        return ResponseEntity.ok(Map.of("isFollowing", true));
    }

    @DeleteMapping("/{userId}/follow")
    public ResponseEntity<Map<String, Boolean>> unfollowUser(
            @AuthenticationPrincipal User currentUser,
            @PathVariable Long userId) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        log.info("User {} unfollowing user {}", currentUser.getId(), userId);
        followService.unfollow(currentUser, userId);
        return ResponseEntity.ok(Map.of("isFollowing", false));
    }

    @GetMapping("/{userId}/following")
    public ResponseEntity<UserListResp> getFollowing(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        User targetUser = userRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if ((currentUser == null || !currentUser.getId().equals(userId))
                && targetUser.isHideFollowing()) {
            throw new ForbiddenException("对方已隐藏关注列表");
        }
        Page<UserFollow> followingPage = followService.getFollowing(userId, PageRequest.of(page, pageSize));
        var users = followingPage.getContent().stream()
                .map(UserFollow::getFollowing)
                .map(u -> userService.toProfile(u, currentUser))
                .toList();
        return ResponseEntity.ok(new UserListResp(users, followingPage.getTotalElements(), page, pageSize));
    }

    @GetMapping("/{userId}/followers")
    public ResponseEntity<UserListResp> getFollowers(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        User targetUser = userRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if ((currentUser == null || !currentUser.getId().equals(userId))
                && targetUser.isHideFollowers()) {
            throw new ForbiddenException("对方已隐藏粉丝列表");
        }
        Page<UserFollow> followerPage = followService.getFollowers(userId, PageRequest.of(page, pageSize));
        var users = followerPage.getContent().stream()
                .map(UserFollow::getFollower)
                .map(u -> userService.toProfile(u, currentUser))
                .toList();
        return ResponseEntity.ok(new UserListResp(users, followerPage.getTotalElements(), page, pageSize));
    }

    @GetMapping("/{userId}/mutual")
    public ResponseEntity<UserListResp> getMutual(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        Page<UserFollow> mutualPage = followService.getMutualFollows(userId, PageRequest.of(page, pageSize));
        var users = mutualPage.getContent().stream()
                .map(UserFollow::getFollowing)
                .map(u -> userService.toProfile(u, currentUser))
                .toList();
        return ResponseEntity.ok(new UserListResp(users, mutualPage.getTotalElements(), page, pageSize));
    }
}
