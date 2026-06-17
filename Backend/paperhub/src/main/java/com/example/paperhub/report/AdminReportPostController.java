package com.example.paperhub.report;

import com.example.paperhub.admin.ReportStatus;
import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import com.example.paperhub.report.dto.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Admin-facing post report and moderation controller.
 */
@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = "*")
public class AdminReportPostController {

    private final ReportPostAdminService reportPostAdminService;

    public AdminReportPostController(ReportPostAdminService reportPostAdminService) {
        this.reportPostAdminService = reportPostAdminService;
    }

    @GetMapping("/report/posts")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> getAllReports(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {

        try {
            Pageable pageable = PageRequest.of(page, pageSize);
            Page<ReportPost> reportPage;

            if (status != null && !status.isEmpty()) {
                ReportStatus reportStatus = ReportStatus.valueOf(status.toUpperCase());
                reportPage = reportPostAdminService.getReportsByStatus(reportStatus, pageable);
            } else {
                reportPage = reportPostAdminService.getAllReports(pageable);
            }

            var list = reportPage.getContent().stream()
                    .map(r -> new ReportListItemResponse(
                            r.getId(),
                            r.getReporter().getId(),
                            r.getReporter().getName(),
                            r.getReporter().getEmail(),
                            r.getPost().getId(),
                            r.getPost().getTitle(),
                            r.getPost().getAuthor().getId(),
                            r.getPost().getAuthor().getName(),
                            r.getDescription(),
                            r.getStatus().name(),
                            r.getReportTime(),
                            r.getAdmin() != null ? r.getAdmin().getId() : null,
                            r.getAdmin() != null ? r.getAdmin().getName() : null,
                            r.getHandleTime(),
                            r.getHandleResult(),
                            r.getPost().getStatus() != null ? r.getPost().getStatus().name() : null
                    ))
                    .toList();

            ReportListResponse response = new ReportListResponse(
                    list,
                    reportPage.getTotalElements(),
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

    @PostMapping("/report/{id}/remove")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> removePost(
            @PathVariable Long id,
            @Valid @RequestBody RemovePostRequest request,
            @AuthenticationPrincipal User currentUser) {

        try {
            ReportPost report = reportPostAdminService.removePost(id, request.reason(), currentUser);

            return ResponseEntity.ok(
                    new OperationResponse(
                            true,
                            "帖子已下架",
                            Map.of(
                                    "reportId", report.getId(),
                                    "postId", report.getPost().getId(),
                                    "status", report.getStatus().name(),
                                    "handleResult", report.getHandleResult()
                            )
                    )
            );
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    @PostMapping("/report/{id}/ignore")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> ignoreReport(
            @PathVariable Long id,
            @Valid @RequestBody IgnoreReportRequest request,
            @AuthenticationPrincipal User currentUser) {

        try {
            ReportPost report = reportPostAdminService.ignoreReport(
                    id,
                    request.reason() != null ? request.reason() : "未发现违规",
                    currentUser
            );

            return ResponseEntity.ok(
                    new OperationResponse(
                            true,
                            "已忽略该举报",
                            Map.of(
                                    "reportId", report.getId(),
                                    "status", report.getStatus().name(),
                                    "handleResult", report.getHandleResult()
                            )
                    )
            );
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    @PostMapping("/post/{id}/approve")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> approvePost(
            @PathVariable Long id,
            @AuthenticationPrincipal User currentUser) {

        try {
            Post post = reportPostAdminService.approvePost(id, currentUser);

            return ResponseEntity.ok(
                    new OperationResponse(
                            true,
                            "审核通过，帖子已恢复正常",
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

    @PostMapping("/post/{id}/reject")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> rejectPost(
            @PathVariable Long id,
            @Valid @RequestBody RejectPostRequest request,
            @AuthenticationPrincipal User currentUser) {

        try {
            Post post = reportPostAdminService.rejectPost(id, request.reason(), currentUser);

            return ResponseEntity.ok(
                    new OperationResponse(
                            true,
                            "审核未通过，帖子已重新下架",
                            Map.of(
                                    "postId", post.getId(),
                                    "status", post.getStatus().name(),
                                    "hiddenReason", post.getHiddenReason()
                            )
                    )
            );
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    @GetMapping("/post/audit")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> getAuditPosts(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {

        try {
            Pageable pageable = PageRequest.of(page, pageSize);
            Page<Post> postPage = reportPostAdminService.getAuditPosts(pageable);

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

    @GetMapping("/report/count")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> countPendingReports(@AuthenticationPrincipal User currentUser) {
        try {
            long count = reportPostAdminService.countPendingReports();
            return ResponseEntity.ok(Map.of("count", count));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }
}
