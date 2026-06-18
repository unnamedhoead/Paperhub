package com.example.paperhub.user;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.favorite.FavoriteService;
import com.example.paperhub.follow.FollowService;
import com.example.paperhub.follow.UserFollow;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostMapper;
import com.example.paperhub.post.PostService;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.user.dto.ProfileResp;
import com.example.paperhub.user.dto.UpdateProfileReq;
import com.example.paperhub.user.dto.UserListResp;
import jakarta.validation.Valid;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * 用户个人资料 API：查看/编辑资料、搜索、帖子列表、收藏列表。
 */
@RestController
@RequestMapping("/users")
@CrossOrigin(origins = "*")
public class UserProfileController {

    private final UserService userService;
    private final FollowService followService;
    private final FavoriteService favoriteService;
    private final PostService postService;
    private final PostMapper postMapper;

    public UserProfileController(UserService userService,
                                  FollowService followService,
                                  FavoriteService favoriteService,
                                  PostService postService,
                                  PostMapper postMapper) {
        this.userService = userService;
        this.followService = followService;
        this.favoriteService = favoriteService;
        this.postService = postService;
        this.postMapper = postMapper;
    }

    /**
     * 获取当前登录用户的个人资料。
     */
    @GetMapping("/me")
    public ResponseEntity<ProfileResp> getCurrentUser(@AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        return ResponseEntity.ok(userService.toProfile(currentUser));
    }

    /**
     * 获取指定用户的公开资料。
     */
    @GetMapping("/{userId}")
    public ResponseEntity<ProfileResp> getUserProfile(
            @PathVariable Long userId,
            @AuthenticationPrincipal User currentUser) {
        User target = userService.getUserById(userId);
        return ResponseEntity.ok(userService.toProfile(target, currentUser));
    }

    /**
     * 更新当前登录用户的基础资料。
     */
    @PutMapping("/me")
    public ResponseEntity<ProfileResp> updateProfile(
            @AuthenticationPrincipal User currentUser,
            @Valid @RequestBody UpdateProfileReq req) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        User updated = userService.updateProfile(currentUser, req);
        return ResponseEntity.ok(userService.toProfile(updated));
    }

    /**
     * 获取用户发布的帖子。
     */
    @GetMapping("/{userId}/posts")
    public ResponseEntity<PostDtos.PostListResp> getUserPosts(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        Page<Post> postPage = postService.getPostsByAuthor(userId, page, pageSize);
        Long viewerId = currentUser != null ? currentUser.getId() : null;
        List<PostDtos.PostResp> posts = postPage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, viewerId))
                .toList();
        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts,
                postPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    /**
     * 获取用户收藏的帖子。
     */
    @GetMapping("/{userId}/favorites")
    public ResponseEntity<PostDtos.PostListResp> getFavorites(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        User target = userService.getUserById(userId);
        // 隐私控制：非本人且对方未公开收藏时禁止访问
        if ((currentUser == null || !currentUser.getId().equals(userId))
                && !target.isPublicFavorites()) {
            throw new NotFoundException("对方已隐藏收藏");
        }

        var pageable = PageRequest.of(page - 1, pageSize);
        var favoritePage = favoriteService.getFavoritePosts(userId, pageable);
        Long viewerId = currentUser != null ? currentUser.getId() : null;
        List<PostDtos.PostResp> posts = favoritePage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, viewerId))
                .toList();
        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts,
                favoritePage.getTotalElements(),
                page,
                pageSize
        ));
    }

    /**
     * 搜索用户（用于@功能）。
     * GET /users/search?q=name&type=following|all
     * type=following: 只搜索关注的人
     * type=all: 搜索所有用户
     */
    @GetMapping("/search")
    public ResponseEntity<UserListResp> searchUsers(
            @RequestParam String q,
            @RequestParam(defaultValue = "all") String type,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }

        List<User> users;
        if ("following".equals(type)) {
            // 只搜索关注的人
            Page<UserFollow> followingPage = followService.getFollowing(
                    currentUser.getId(), PageRequest.of(page, pageSize));
            users = followingPage.getContent().stream()
                    .map(UserFollow::getFollowing)
                    .filter(u -> {
                        String name = u.getName();
                        if (name == null || name.isEmpty()) {
                            name = u.getEmail();
                        }
                        return name != null && name.toLowerCase().contains(q.toLowerCase());
                    })
                    .sorted((user1, user2) -> {
                        double score1 = calculateUserSortScore(user1, q, currentUser);
                        double score2 = calculateUserSortScore(user2, q, currentUser);
                        return Double.compare(score2, score1);
                    })
                    .toList();
            return ResponseEntity.ok(new UserListResp(
                    users.stream().map(u -> userService.toProfile(u, currentUser)).toList(),
                    users.size(),
                    page,
                    pageSize
            ));
        } else {
            // 搜索所有用户
            List<User> allUsers = userService.searchByName(q);

            List<User> sortedUsers = allUsers.stream()
                    .sorted((user1, user2) -> {
                        double score1 = calculateUserSortScore(user1, q, currentUser);
                        double score2 = calculateUserSortScore(user2, q, currentUser);
                        return Double.compare(score2, score1);
                    })
                    .collect(Collectors.toList());

            int start = page * pageSize;
            int end = Math.min(start + pageSize, sortedUsers.size());
            users = start < sortedUsers.size() ? sortedUsers.subList(start, end) : List.of();
            return ResponseEntity.ok(new UserListResp(
                    users.stream().map(u -> userService.toProfile(u, currentUser)).toList(),
                    sortedUsers.size(),
                    page,
                    pageSize
            ));
        }
    }

    // ── 搜索排序辅助方法 ──

    private double calculateUserSortScore(User user, String query, User currentUser) {
        double nameMatchScore = calculateNameMatchScore(user, query);
        double heatScore = calculateUserHeatScore(user);
        return nameMatchScore * 0.7 + heatScore * 0.3;
    }

    private double calculateNameMatchScore(User user, String query) {
        String userName = user.getName() != null ? user.getName().toLowerCase() : "";
        String queryLower = query.toLowerCase();

        if (userName.equals(queryLower)) {
            return 100.0;
        } else if (userName.startsWith(queryLower)) {
            return 80.0;
        } else if (userName.contains(queryLower)) {
            return 60.0;
        } else {
            return 0.0;
        }
    }

    private double calculateUserHeatScore(User user) {
        ProfileResp profile = userService.toProfile(user);
        long followersCount = profile.followersCount();
        long likesReceived = profile.likesCount();
        long postsCount = profile.postsCount();
        long favoritesReceived = profile.favoritesReceivedCount();

        double rawHeat = followersCount * 1.0 +
                        likesReceived * 2.0 +
                        postsCount * 0.5 +
                        favoritesReceived * 1.5;

        final double MAX_HEAT = 10000.0;
        double normalizedScore = 100.0 * Math.log10(1 + rawHeat) / Math.log10(1 + MAX_HEAT);
        return Math.min(normalizedScore, 100.0);
    }
}
