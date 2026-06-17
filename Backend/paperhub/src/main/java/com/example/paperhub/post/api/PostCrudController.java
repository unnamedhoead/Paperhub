package com.example.paperhub.post.api;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.favorite.FavoriteService;
import com.example.paperhub.like.LikeService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostMapper;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.post.service.PostCrudService;
import com.example.paperhub.post.service.PostDraftService;
import com.example.paperhub.websocket.WebSocketService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Post CRUD endpoints: create, read, update, delete, like, favorite, draft, health, batch.
 */
@RestController
@RequestMapping("/posts")
@CrossOrigin(origins = "*")
public class PostCrudController {

    private static final Logger log = LoggerFactory.getLogger(PostCrudController.class);

    private final PostCrudService postCrudService;
    private final PostDraftService postDraftService;
    private final LikeService likeService;
    private final FavoriteService favoriteService;
    private final PostMapper postMapper;
    private final WebSocketService webSocketService;

    public PostCrudController(PostCrudService postCrudService,
                              PostDraftService postDraftService,
                              LikeService likeService,
                              FavoriteService favoriteService,
                              PostMapper postMapper,
                              WebSocketService webSocketService) {
        this.postCrudService = postCrudService;
        this.postDraftService = postDraftService;
        this.likeService = likeService;
        this.favoriteService = favoriteService;
        this.postMapper = postMapper;
        this.webSocketService = webSocketService;
    }

    /**
     * 健康检查端点
     * GET /posts/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
                "status", "ok",
                "message", "后端服务运行正常",
                "timestamp", java.time.Instant.now().toString()
        ));
    }

    /**
     * 获取帖子详情
     * GET /posts/{postId}
     */
    @GetMapping("/{postId}")
    public ResponseEntity<PostDtos.PostResp> getPost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {

        Post post = postCrudService.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        postCrudService.incrementViewsCount(postId);

        Long userId = (user != null) ? user.getId() : null;
        PostDtos.PostResp resp = postMapper.toPostResp(post, userId);
        return ResponseEntity.ok(resp);
    }

    /**
     * 创建帖子
     * POST /posts
     */
    @PostMapping
    public ResponseEntity<PostDtos.PostResp> createPost(
            @Valid @RequestBody PostDtos.CreatePostReq req,
            @AuthenticationPrincipal User user) {
        log.info("Creating post, title={}", req.title());

        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        validateExternalLinks(req.externalLinks());

        Post post = postCrudService.createPost(
                req.title(), req.content(), user,
                req.media() != null ? req.media() : new ArrayList<>(),
                req.mainDiscipline(), req.doi(), req.journal(), req.year(),
                req.externalLinks() != null ? req.externalLinks() : new ArrayList<>(),
                req.arxivId(),
                req.arxivAuthors() != null ? req.arxivAuthors() : new ArrayList<>(),
                req.arxivPublishedDate(),
                req.arxivCategories() != null ? req.arxivCategories() : new ArrayList<>(),
                req.references() != null ? req.references() : new ArrayList<>(),
                req.status() != null ? req.status() : "NORMAL"
        );

        PostDtos.PostResp resp = postMapper.toPostResp(post, user.getId());
        return ResponseEntity.status(201).body(resp);
    }

    /**
     * 更新帖子（编辑）
     * PUT /posts/{postId}
     */
    @PutMapping("/{postId}")
    public ResponseEntity<PostDtos.PostResp> updatePost(
            @PathVariable Long postId,
            @Valid @RequestBody PostDtos.CreatePostReq req,
            @AuthenticationPrincipal User user) {
        log.info("Updating post, postId={}", postId);

        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        validateExternalLinks(req.externalLinks());

        try {
            Post post = postCrudService.updatePost(
                    postId, user,
                    req.title(), req.content(),
                    req.media() != null ? req.media() : new ArrayList<>(),
                    req.mainDiscipline(), req.doi(), req.journal(), req.year(),
                    req.externalLinks() != null ? req.externalLinks() : new ArrayList<>(),
                    req.arxivId(),
                    req.arxivAuthors() != null ? req.arxivAuthors() : new ArrayList<>(),
                    req.arxivPublishedDate(),
                    req.arxivCategories() != null ? req.arxivCategories() : new ArrayList<>(),
                    req.references() != null ? req.references() : new ArrayList<>(),
                    req.status()
            );
            PostDtos.PostResp resp = postMapper.toPostResp(post, user.getId());
            return ResponseEntity.ok(resp);
        } catch (IllegalArgumentException ex) {
            throw new NotFoundException(ex.getMessage());
        } catch (SecurityException ex) {
            throw new ForbiddenException(ex.getMessage());
        }
    }

    /**
     * 删除帖子
     * DELETE /posts/{postId}
     */
    @DeleteMapping("/{postId}")
    public ResponseEntity<Void> deletePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {

        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }

        try {
            postCrudService.deletePost(postId, user.getId());
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException ex) {
            throw new NotFoundException(ex.getMessage());
        } catch (SecurityException ex) {
            throw new ForbiddenException(ex.getMessage());
        }
    }

    /**
     * 批量查询帖子（for P7 历史 N+1 优化）
     * GET /posts/batch?ids=1,2,3
     */
    @GetMapping("/batch")
    public ResponseEntity<List<PostDtos.PostResp>> getPostsByIds(
            @RequestParam(required = false) List<Long> ids,
            @AuthenticationPrincipal User user) {
        if (ids == null || ids.isEmpty()) {
            throw new BadRequestException("ids must not be empty");
        }
        Long userId = (user != null) ? user.getId() : null;
        List<PostDtos.PostResp> posts = ids.stream()
                .map(id -> postCrudService.findById(id)
                        .orElseThrow(() -> new NotFoundException("帖子不存在: " + id)))
                .map(post -> postMapper.toPostResp(post, userId))
                .toList();
        return ResponseEntity.ok(posts);
    }

    /**
     * 点赞帖子
     * POST /posts/{postId}/like
     */
    @PostMapping("/{postId}/like")
    public ResponseEntity<PostDtos.LikeResp> likePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        log.info("Like post, postId={}, userId={}", postId, user != null ? user.getId() : null);

        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }

        boolean result = likeService.likePost(postId, user);
        log.info("Like result: {}", result);

        long likesCount = likeService.getPostLikesCount(postId);
        boolean isLiked = likeService.isPostLiked(postId, user.getId());

        try {
            webSocketService.sendPostLikeUpdate(postId, (int) likesCount, isLiked);
        } catch (Exception wsEx) {
            log.warn("WebSocket推送失败（不影响主流程）: {}", wsEx.getMessage());
        }

        PostDtos.LikeResp resp = new PostDtos.LikeResp((int) likesCount, isLiked);
        return ResponseEntity.ok(resp);
    }

    /**
     * 取消点赞帖子
     * DELETE /posts/{postId}/like
     */
    @DeleteMapping("/{postId}/like")
    public ResponseEntity<PostDtos.LikeResp> unlikePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        log.info("Unlike post, postId={}, userId={}", postId, user != null ? user.getId() : null);

        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }

        boolean result = likeService.unlikePost(postId, user);
        log.info("Unlike result: {}", result);

        long likesCount = likeService.getPostLikesCount(postId);
        boolean isLiked = likeService.isPostLiked(postId, user.getId());

        try {
            webSocketService.sendPostLikeUpdate(postId, (int) likesCount, isLiked);
        } catch (Exception wsEx) {
            log.warn("WebSocket推送失败（不影响主流程）: {}", wsEx.getMessage());
        }

        PostDtos.LikeResp resp = new PostDtos.LikeResp((int) likesCount, isLiked);
        return ResponseEntity.ok(resp);
    }

    /**
     * 收藏帖子
     * POST /posts/{postId}/favorite
     */
    @PostMapping("/{postId}/favorite")
    public ResponseEntity<PostDtos.FavoriteResp> favoritePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        try {
            favoriteService.favoritePost(postId, user);
            long favoritesCount = favoriteService.countFavoritesByPostId(postId);
            boolean isSaved = favoriteService.isFavorite(postId, user.getId());
            return ResponseEntity.ok(new PostDtos.FavoriteResp((int) favoritesCount, isSaved));
        } catch (IllegalArgumentException ex) {
            throw new NotFoundException(ex.getMessage());
        }
    }

    /**
     * 取消收藏帖子
     * DELETE /posts/{postId}/favorite
     */
    @DeleteMapping("/{postId}/favorite")
    public ResponseEntity<PostDtos.FavoriteResp> unfavoritePost(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        favoriteService.unfavoritePost(postId, user);
        long favoritesCount = favoriteService.countFavoritesByPostId(postId);
        boolean isSaved = favoriteService.isFavorite(postId, user.getId());
        return ResponseEntity.ok(new PostDtos.FavoriteResp((int) favoritesCount, isSaved));
    }

    /**
     * 保存为草稿（用户主动保存）
     * POST /posts/{postId}/save-draft
     */
    @PostMapping("/{postId}/save-draft")
    public ResponseEntity<Map<String, Object>> saveDraft(
            @PathVariable Long postId,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        try {
            Post post = postDraftService.saveDraft(postId, user.getId());
            return ResponseEntity.ok(Map.of(
                    "message", "已保存为草稿",
                    "postId", post.getId(),
                    "status", post.getStatus().name()
            ));
        } catch (IllegalArgumentException ex) {
            throw new NotFoundException(ex.getMessage());
        } catch (SecurityException ex) {
            throw new ForbiddenException(ex.getMessage());
        }
    }

    /**
     * 获取用户的草稿列表
     * GET /posts/drafts?page=1&pageSize=20
     */
    @GetMapping("/drafts")
    public ResponseEntity<PostDtos.PostListResp> getDrafts(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User user) {
        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }

        org.springframework.data.domain.Page<Post> postPage = postDraftService.getUserDrafts(user.getId(), page, pageSize);
        List<PostDtos.PostResp> posts = postPage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, user.getId()))
                .toList();

        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts, postPage.getTotalElements(), page, pageSize
        ));
    }

    private void validateExternalLinks(List<String> externalLinks) {
        if (externalLinks != null) {
            for (String url : externalLinks) {
                if (!isValidUrl(url)) {
                    throw new BadRequestException("外部链接格式非法: " + url);
                }
            }
        }
    }

    private boolean isValidUrl(String url) {
        if (url == null) return false;
        String pattern = "^(https?://)[^\\s]+$";
        if (!url.matches(pattern)) return false;
        String lower = url.toLowerCase();
        return !(lower.startsWith("javascript:") || lower.startsWith("data:"));
    }
}
