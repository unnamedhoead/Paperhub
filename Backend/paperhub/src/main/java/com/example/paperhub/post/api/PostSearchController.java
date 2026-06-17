package com.example.paperhub.post.api;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostMapper;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.post.service.PostSearchService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Search endpoints: keyword and tag search with hot/new sorting.
 */
@RestController
@RequestMapping("/posts")
@CrossOrigin(origins = "*")
public class PostSearchController {

    private static final Logger log = LoggerFactory.getLogger(PostSearchController.class);

    private final PostSearchService postSearchService;
    private final PostMapper postMapper;

    public PostSearchController(PostSearchService postSearchService, PostMapper postMapper) {
        this.postSearchService = postSearchService;
        this.postMapper = postMapper;
    }

    /**
     * 搜索帖子
     * GET /posts/search?q=keyword&type=keyword|tag&sort=hot|new&page=1&pageSize=20
     */
    @GetMapping("/search")
    public ResponseEntity<PostDtos.PostListResp> searchPosts(
            @RequestParam String q,
            @RequestParam(defaultValue = "keyword") String type,
            @RequestParam(defaultValue = "hot") String sort,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @AuthenticationPrincipal User currentUser) {

        Page<Post> postPage = postSearchService.searchPosts(q, type, sort, page, pageSize);
        Long viewerId = currentUser != null ? currentUser.getId() : null;
        List<PostDtos.PostResp> posts = postPage.getContent().stream()
                .map(post -> postMapper.toPostResp(post, viewerId))
                .toList();
        return ResponseEntity.ok(new PostDtos.PostListResp(
                posts, postPage.getTotalElements(), page, pageSize
        ));
    }
}
