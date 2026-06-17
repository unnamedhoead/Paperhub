package com.example.paperhub.follow;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.UnauthorizedException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/follows")
public class FollowController {

    private static final Logger log = LoggerFactory.getLogger(FollowController.class);
    private final FollowService followService;

    public FollowController(FollowService followService) {
        this.followService = followService;
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
}
