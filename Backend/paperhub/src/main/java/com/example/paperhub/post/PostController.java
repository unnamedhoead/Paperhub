package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.report.ReportPost;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * Legacy controller — only the report endpoint remains here.
 * P6 will migrate this to the admin/report domain.
 * All other endpoints have been moved to the post/api/ sub-package.
 */
@RestController
@RequestMapping("/posts")
@CrossOrigin(origins = "*")
public class PostController {

    private static final Logger log = LoggerFactory.getLogger(PostController.class);

    private final PostService postService;

    public PostController(PostService postService) {
        this.postService = postService;
    }

    /**
     * 举报帖子
     * POST /posts/{postId}/report
     */
    @PostMapping("/{postId}/report")
    public ResponseEntity<?> reportPost(
            @PathVariable Long postId,
            @RequestBody Map<String, String> request,
            @AuthenticationPrincipal User user) {

        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }

        String description = request.get("description");
        if (description == null || description.trim().isEmpty()) {
            throw new BadRequestException("举报描述不能为空");
        }

        try {
            ReportPost report = postService.reportPost(postId, description, user);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "举报成功，我们会尽快处理");
            response.put("reportId", report.getId());

            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException ex) {
            throw new BadRequestException(ex.getMessage());
        }
    }
}
