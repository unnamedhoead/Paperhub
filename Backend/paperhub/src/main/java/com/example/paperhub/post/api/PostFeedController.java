package com.example.paperhub.post.api;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostMapper;
import com.example.paperhub.post.RecommendationService;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.post.service.PostFeedService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Feed endpoints: main post listing, following feed, recommendations.
 */
@RestController
@RequestMapping("/posts")
@CrossOrigin(origins = "*")
public class PostFeedController {

    private static final Logger log = LoggerFactory.getLogger(PostFeedController.class);

    private final PostFeedService postFeedService;
    private final RecommendationService recommendationService;
    private final PostMapper postMapper;

    public PostFeedController(PostFeedService postFeedService,
                              RecommendationService recommendationService,
                              PostMapper postMapper) {
        this.postFeedService = postFeedService;
        this.recommendationService = recommendationService;
        this.postMapper = postMapper;
    }

    /**
     * 获取帖子列表
     * GET /posts?page=1&pageSize=20&tag=信息科学（CS）
     */
    @GetMapping
    public ResponseEntity<PostDtos.PostListResp> getPosts(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @RequestParam(required = false) String tag,
            @AuthenticationPrincipal User user) {

        Page<Post> postPage = postFeedService.getPosts(page, pageSize, tag);
        Long userId = (user != null) ? user.getId() : null;

        List<PostDtos.PostResp> posts = postPage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, userId))
                .toList();

        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts, postPage.getTotalElements(), page, pageSize
        ));
    }

    /**
     * 获取"关注"信息流：只返回当前登录用户关注的作者发布的帖子。
     * GET /posts/following?page=1&pageSize=20
     */
    @GetMapping("/following")
    public ResponseEntity<PostDtos.PostListResp> getFollowingFeed(
            @AuthenticationPrincipal User user,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize) {

        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }

        Page<Post> postPage = postFeedService.getFollowingFeed(user.getId(), page, pageSize);
        List<PostDtos.PostResp> posts = postPage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, user.getId()))
                .toList();

        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts, postPage.getTotalElements(), page, pageSize
        ));
    }

    /**
     * 获取首页推荐帖子列表。
     * - 登录用户：按推荐算法排序
     * - 未登录用户：退化为普通时间排序
     * GET /posts/recommendations?page=1&pageSize=20
     */
    @GetMapping("/recommendations")
    public ResponseEntity<PostDtos.PostListResp> getRecommendations(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User user) {

        if (user == null) {
            Page<Post> postPage = postFeedService.getPosts(page, pageSize);
            List<PostDtos.PostResp> posts = postPage.getContent().stream()
                    .map(post -> postMapper.toPostResp(post, null))
                    .toList();
            return ResponseEntity.ok(new PostDtos.PostListResp(
                    posts, postPage.getTotalElements(), page, pageSize
            ));
        }

        Page<Post> postPage = recommendationService.getRecommendations(user.getId(), page, pageSize);
        List<PostDtos.PostResp> posts = postPage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, user.getId()))
                .toList();

        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts, postPage.getTotalElements(), page, pageSize
        ));
    }
}
