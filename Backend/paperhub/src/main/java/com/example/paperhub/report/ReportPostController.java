package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.report.dto.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * User-facing post report and post workflow controller.
 */
@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class ReportPostController {

    private final ReportPostUserService reportPostUserService;

    public ReportPostController(ReportPostUserService reportPostUserService) {
        this.reportPostUserService = reportPostUserService;
    }

    @PostMapping("/report/post")
    public ResponseEntity<?> reportPost(
            @Valid @RequestBody ReportPostRequest request,
            @AuthenticationPrincipal User currentUser) {
        try {
            ReportPost report = reportPostUserService.reportPost(
                    request.postId(),
                    request.description(),
                    currentUser
            );

            ReportPostResponse response = new ReportPostResponse(
                    report.getId(),
                    report.getReporter().getId(),
                    report.getReporter().getName(),
                    report.getPost().getId(),
                    report.getPost().getTitle(),
                    report.getDescription(),
                    report.getStatus().name(),
                    report.getReportTime(),
                    "举报成功，我们会尽快处理"
            );

            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    @GetMapping("/post/{id}")
    public ResponseEntity<?> getPostDetail(
            @PathVariable Long id,
            @AuthenticationPrincipal User currentUser) {
        try {
            PostDetailResponse detail = reportPostUserService.getPostDetail(id, currentUser);

            if (!detail.visible()) {
                return ResponseEntity.status(403).body(
                        new OperationResponse(false, detail.message(), null)
                );
            }

            return ResponseEntity.ok(detail);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    @PostMapping("/post/{id}/draft")
    public ResponseEntity<?> saveDraft(
            @PathVariable Long id,
            @Valid @RequestBody SaveDraftRequest request,
            @AuthenticationPrincipal User currentUser) {
        try {
            Post post = reportPostUserService.saveDraft(
                    id,
                    request.title(),
                    request.content(),
                    request.media(),
                    request.tags(),
                    currentUser
            );

            return ResponseEntity.ok(
                    new OperationResponse(
                            true,
                            "草稿保存成功",
                            Map.of(
                                    "postId", post.getId(),
                                    "status", post.getStatus().name()
                            )
                    )
            );
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    @PostMapping("/post/{id}/submit")
    public ResponseEntity<?> submitForAudit(
            @PathVariable Long id,
            @AuthenticationPrincipal User currentUser) {
        try {
            Post post = reportPostUserService.submitForAudit(id, currentUser);

            return ResponseEntity.ok(
                    new OperationResponse(
                            true,
                            "已提交审核，请等待管理员审核",
                            Map.of(
                                    "postId", post.getId(),
                                    "status", post.getStatus().name()
                            )
                    )
            );
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    @GetMapping("/post/removed")
    public ResponseEntity<?> getAuthorRemovedPosts(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        try {
            if (currentUser == null) {
                return ResponseEntity.status(401).body(
                        new OperationResponse(false, "用户未登录", null)
                );
            }

            Pageable pageable = PageRequest.of(page, pageSize);
            Page<Post> postPage = reportPostUserService.getAuthorRemovedPosts(
                    currentUser.getId(),
                    pageable
            );

            var list = postPage.getContent().stream()
                    .map(p -> new PostListItemResponse(
                            p.getId(),
                            p.getTitle(),
                            p.getAuthor().getId(),
                            p.getAuthor().getName(),
                            p.getAuthor().getEmail(),
                            p.getStatus().name(),
                            p.getHiddenReason(),
                            p.getCreatedAt(),
                            p.getUpdatedAt()
                    ))
                    .toList();

            PostListResponse response = new PostListResponse(
                    list,
                    postPage.getTotalElements(),
                    page,
                    pageSize
            );

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }
}
