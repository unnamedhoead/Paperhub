package com.example.paperhub.report;

import com.example.paperhub.admin.ReportStatus;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.common.security.PermissionUtils;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Admin-facing report & post moderation service.
 * Handles: list reports, remove post, ignore report, approve/reject audit, count pending.
 */
@Service
public class ReportPostAdminService {

    private final ReportPostRepository reportPostRepository;
    private final PostRepository postRepository;
    private final com.example.paperhub.notification.NotificationService notificationService;

    public ReportPostAdminService(ReportPostRepository reportPostRepository,
                                   PostRepository postRepository,
                                   com.example.paperhub.notification.NotificationService notificationService) {
        this.reportPostRepository = reportPostRepository;
        this.postRepository = postRepository;
        this.notificationService = notificationService;
    }

    private void ensureAdmin(User admin) {
        PermissionUtils.ensureAdmin(admin);
    }

    public Page<ReportPost> getAllReports(Pageable pageable) {
        return reportPostRepository.findAllByOrderByReportTimeDesc(pageable);
    }

    public Page<ReportPost> getReportsByStatus(ReportStatus status, Pageable pageable) {
        return reportPostRepository.findByStatus(status, pageable);
    }

    @Transactional
    public ReportPost removePost(Long reportId, String reason, User admin) {
        ensureAdmin(admin);

        ReportPost report = reportPostRepository.findById(reportId)
                .orElseThrow(() -> new NotFoundException("举报记录不存在"));

        if (report.getStatus() != ReportStatus.PENDING) {
            throw new BadRequestException("该举报已被处理");
        }

        Post post = report.getPost();
        post.setStatus(PostStatus.DRAFT);
        post.setHiddenReason(reason != null ? reason : "违规内容");
        post.setUpdatedByAdmin(admin.getId());
        post.setVisibleToAuthor(true);
        post.setUpdatedAt(Instant.now());
        postRepository.save(post);

        report.setStatus(ReportStatus.PROCESSED);
        report.setAdmin(admin);
        report.setHandleTime(Instant.now());
        report.setHandleResult("已打回，原因：" + (reason != null ? reason : "违规内容"));
        report.setPostStatusAfter(PostStatus.DRAFT);

        notificationService.createPostRemovedNotification(admin, post.getId(), reason);

        return reportPostRepository.save(report);
    }

    @Transactional
    public ReportPost ignoreReport(Long reportId, String reason, User admin) {
        ensureAdmin(admin);

        ReportPost report = reportPostRepository.findById(reportId)
                .orElseThrow(() -> new NotFoundException("举报记录不存在"));

        if (report.getStatus() != ReportStatus.PENDING) {
            throw new BadRequestException("该举报已被处理");
        }

        report.setStatus(ReportStatus.IGNORED);
        report.setAdmin(admin);
        report.setHandleTime(Instant.now());
        report.setHandleResult("已忽略，原因：" + (reason != null ? reason : "未发现违规"));
        report.setPostStatusAfter(PostStatus.NORMAL);

        return reportPostRepository.save(report);
    }

    @Transactional
    public Post approvePost(Long postId, User admin) {
        ensureAdmin(admin);

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        if (post.getStatus() != PostStatus.AUDIT) {
            throw new BadRequestException("只有审核中的帖子才能审核通过");
        }

        post.setStatus(PostStatus.NORMAL);
        post.setHiddenReason(null);
        post.setVisibleToAuthor(true);
        post.setUpdatedByAdmin(admin.getId());
        post.setUpdatedAt(Instant.now());

        notificationService.createPostApprovedNotification(admin, post.getId());

        return postRepository.save(post);
    }

    @Transactional
    public Post rejectPost(Long postId, String reason, User admin) {
        ensureAdmin(admin);

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        if (post.getStatus() != PostStatus.AUDIT) {
            throw new BadRequestException("只有审核中的帖子才能拒绝");
        }

        post.setStatus(PostStatus.DRAFT);
        post.setHiddenReason(reason != null ? reason : "审核未通过");
        post.setUpdatedByAdmin(admin.getId());
        post.setUpdatedAt(Instant.now());

        notificationService.createPostRejectedNotification(admin, post.getId(), reason);

        return postRepository.save(post);
    }

    public Page<Post> getAuditPosts(Pageable pageable) {
        return postRepository.findByStatus(PostStatus.AUDIT, pageable);
    }

    public long countPendingReports() {
        return reportPostRepository.countByStatus(ReportStatus.PENDING);
    }
}
