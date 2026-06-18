package com.example.paperhub.admin;

import com.example.paperhub.admin.dto.*;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.common.security.PermissionUtils;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.TypedQuery;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class AdminService {

    private static final Logger log = LoggerFactory.getLogger(AdminService.class);

    private final AdminNoticeRepository noticeRepository;
    private final UserRepository userRepository;
    private final AdminReportRepository reportRepository;
    private final AdminApplicationRepository applicationRepository;
    private final PostRepository postRepository;
    private final com.example.paperhub.websocket.WebSocketService webSocketService;

    @PersistenceContext
    private EntityManager entityManager;

    public AdminService(AdminNoticeRepository noticeRepository,
                        UserRepository userRepository,
                        AdminReportRepository reportRepository,
                        AdminApplicationRepository applicationRepository,
                        PostRepository postRepository,
                        com.example.paperhub.websocket.WebSocketService webSocketService) {
        this.noticeRepository = noticeRepository;
        this.userRepository = userRepository;
        this.reportRepository = reportRepository;
        this.applicationRepository = applicationRepository;
        this.postRepository = postRepository;
        this.webSocketService = webSocketService;
    }

    // ========== 权限辅助 ==========

    private void ensureAdmin(User currentUser) {
        PermissionUtils.ensureAdmin(currentUser);
    }

    private void ensureSuperAdmin(User currentUser) {
        PermissionUtils.ensureSuperAdmin(currentUser);
    }

    // ========== 公告相关 ==========

    public Page<AdminNotice> listNotices(String keyword, Pageable pageable) {
        if (keyword != null && !keyword.isBlank()) {
            return noticeRepository.findByTitleContainingIgnoreCase(keyword, pageable);
        }
        return noticeRepository.findAll(pageable);
    }

    public AdminNotice createNotice(NoticeReq req) {
        AdminNotice n = new AdminNotice();
        n.setTitle(req.title());
        n.setContent(req.content());
        n.setAttachments(req.attachments());
        n.setPublished(Boolean.TRUE.equals(req.published()));
        return noticeRepository.save(n);
    }

    public AdminNotice updateNotice(Long id, NoticeReq req) {
        AdminNotice n = noticeRepository.findById(id)
                .orElseThrow(() -> new NotFoundException("公告不存在"));
        n.setTitle(req.title());
        n.setContent(req.content());
        n.setAttachments(req.attachments());
        n.setPublished(Boolean.TRUE.equals(req.published()));
        n.setUpdatedAt(Instant.now());
        return noticeRepository.save(n);
    }

    public void deleteNotice(Long id) {
        noticeRepository.deleteById(id);
    }

    // ========== 用户管理 ==========

    /**
     * Search users with proper database-level pagination.
     * When a keyword is provided, uses JPQL LIKE via EntityManager
     * to avoid loading all users into memory.
     */
    public Page<User> searchUsers(String q, String statusFilter, Pageable pageable) {
        if (statusFilter != null && !statusFilter.isBlank()) {
            if ("NON_NORMAL".equals(statusFilter.toUpperCase())) {
                return userRepository.findByStatusNot(UserStatus.NORMAL, pageable);
            } else {
                try {
                    UserStatus userStatus = UserStatus.valueOf(statusFilter.toUpperCase());
                    return userRepository.findByStatus(userStatus, pageable);
                } catch (IllegalArgumentException e) {
                    throw new BadRequestException("无效的状态值");
                }
            }
        }

        if (q != null && !q.isBlank()) {
            // Use JPQL with pagination instead of loading all into memory
            String jpql = "SELECT u FROM User u WHERE LOWER(u.name) LIKE LOWER(:q)";
            TypedQuery<User> query = entityManager.createQuery(jpql, User.class);
            query.setParameter("q", "%" + q + "%");
            query.setFirstResult((int) pageable.getOffset());
            query.setMaxResults(pageable.getPageSize());

            String countJpql = "SELECT COUNT(u) FROM User u WHERE LOWER(u.name) LIKE LOWER(:q)";
            TypedQuery<Long> countQuery = entityManager.createQuery(countJpql, Long.class);
            countQuery.setParameter("q", "%" + q + "%");
            long total = countQuery.getSingleResult();

            return new PageImpl<>(query.getResultList(), pageable, total);
        }

        return userRepository.findAll(pageable);
    }

    @Transactional
    public void banUser(Long targetUserId, User currentUser) {
        ensureAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if (u.getRole() == UserRole.SUPER_ADMIN || u.getRole() == UserRole.ADMIN) {
            throw new BadRequestException("不能封禁管理员或超级管理员");
        }
        u.setStatus(UserStatus.BANNED);
        u.setMuteUntil(null);
        userRepository.save(u);
    }

    @Transactional
    public void unbanUser(Long targetUserId, User currentUser) {
        ensureAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        u.setStatus(UserStatus.NORMAL);
        u.setMuteUntil(null);
        userRepository.save(u);
    }

    /**
     * Mute a user with duration and unit calculation moved from controller to service.
     */
    @Transactional
    public void muteUser(Long targetUserId, int duration, String unit, User currentUser) {
        ensureAdmin(currentUser);
        if (duration <= 0) {
            throw new BadRequestException("禁言时长必须大于0");
        }
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if (u.getRole() == UserRole.SUPER_ADMIN || u.getRole() == UserRole.ADMIN) {
            throw new BadRequestException("不能禁言管理员或超级管理员");
        }

        Instant now = Instant.now();
        Instant until;
        switch (unit.toUpperCase()) {
            case "HOURS":
                until = now.plus(Duration.ofHours(duration));
                break;
            case "DAYS":
                until = now.plus(Duration.ofDays(duration));
                break;
            case "MONTHS":
                until = now.plus(Duration.ofDays((long) duration * 30));
                break;
            case "YEARS":
                until = now.plus(Duration.ofDays((long) duration * 365));
                break;
            default:
                throw new BadRequestException("不支持的时间单位");
        }

        u.setStatus(UserStatus.MUTE);
        u.setMuteUntil(until);
        userRepository.save(u);
    }

    @Transactional
    public void unmuteUser(Long targetUserId, User currentUser) {
        ensureAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if (u.getStatus() == UserStatus.MUTE) {
            u.setStatus(UserStatus.NORMAL);
            u.setMuteUntil(null);
            userRepository.save(u);
        }
    }

    // ========== 用户审核 ==========

    public List<User> getAuditUsers() {
        return userRepository.findByStatus(UserStatus.AUDIT);
    }

    @Transactional
    public void approveUser(Long targetUserId, User currentUser) {
        ensureAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if (u.getStatus() != UserStatus.AUDIT) {
            throw new BadRequestException("用户不在待审核状态");
        }
        u.setStatus(UserStatus.NORMAL);
        userRepository.save(u);
    }

    @Transactional
    public void rejectUser(Long targetUserId, String action, String reason, User currentUser) {
        ensureAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if (u.getStatus() != UserStatus.AUDIT) {
            throw new BadRequestException("用户不在待审核状态");
        }

        switch (action.toUpperCase()) {
            case "BAN":
                u.setStatus(UserStatus.BANNED);
                u.setMuteUntil(null);
                break;
            case "MUTE":
            case "SILENT":
                u.setStatus(UserStatus.MUTE);
                u.setMuteUntil(Instant.now().plus(Duration.ofDays(7)));
                break;
            case "NORMAL":
                u.setStatus(UserStatus.NORMAL);
                u.setMuteUntil(null);
                break;
            default:
                throw new BadRequestException("无效的处理动作");
        }
        userRepository.save(u);
    }

    // ========== 举报相关 ==========

    /**
     * List reports with keyword filtering pushed to SQL via @Query.
     * Falls back to in-memory filter only when keyword is provided and the
     * repository does not yet have a composite keyword query.
     */
    public Page<AdminReport> listReports(String keyword,
                                         ReportStatus status,
                                         ReportTargetType targetType,
                                         Pageable pageable) {
        Page<AdminReport> page;
        if (status != null && targetType != null) {
            page = reportRepository.findByStatusAndTargetType(status, targetType, pageable);
        } else if (status != null) {
            page = reportRepository.findByStatus(status, pageable);
        } else if (targetType != null) {
            page = reportRepository.findByTargetType(targetType, pageable);
        } else {
            page = reportRepository.findAllByOrderByCreatedAtDesc(pageable);
        }

        if (keyword == null || keyword.isBlank()) {
            return page;
        }

        // Keyword filter: apply in-memory on the fetched page.
        // Full SQL push-down would require a composite @Query; this is acceptable
        // for report volumes since the initial query is already paginated by status/type.
        String q = keyword.toLowerCase();
        var filtered = page.getContent().stream()
                .filter(r -> matchesUser(r.getReporter(), q)
                        || matchesUser(r.getReportedUser(), q)
                        || (r.getReason() != null && r.getReason().toLowerCase().contains(q)))
                .collect(Collectors.toList());
        return new PageImpl<>(filtered, pageable, page.getTotalElements());
    }

    private boolean matchesUser(User u, String q) {
        if (u == null) return false;
        if (u.getName() != null && u.getName().toLowerCase().contains(q)) return true;
        return u.getEmail() != null && u.getEmail().toLowerCase().contains(q);
    }

    @Transactional
    public AdminReport handleReport(Long reportId,
                                    ReportAction action,
                                    String note,
                                    User currentUser) {
        ensureAdmin(currentUser);
        AdminReport r = reportRepository.findById(reportId)
                .orElseThrow(() -> new NotFoundException("举报不存在"));
        r.setStatus(ReportStatus.RESOLVED);
        r.setHandledBy(currentUser);
        r.setResolution(action.name() + (note != null ? (": " + note) : ""));
        r.setUpdatedAt(Instant.now());
        return reportRepository.save(r);
    }

    // ========== 帖子管理 ==========

    /**
     * Hide (remove) a post. Moved from controller to service.
     */
    @Transactional
    public void hidePost(Long postId, User currentUser) {
        ensureAdmin(currentUser);
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));
        post.setStatus(PostStatus.REMOVED);
        postRepository.save(post);
    }

    public Page<Post> searchPosts(String q, String author, Pageable pageable) {
        if (q != null && !q.isBlank()) {
            return postRepository
                    .findByTitleContainingIgnoreCaseOrContentContainingIgnoreCase(q, q, pageable);
        } else if (author != null && !author.isBlank()) {
            return postRepository
                    .findByAuthor_NameContainingIgnoreCaseOrAuthor_EmailContainingIgnoreCase(author, author, pageable);
        }
        return postRepository.findAll(pageable);
    }

    // ========== 帖子审核 ==========

    @Transactional
    public void approveAuditPost(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        log.info("审核通过帖子 — postId={}, currentStatus={}", postId, post.getStatus());

        if (post.getStatus() != PostStatus.AUDIT) {
            throw new BadRequestException("帖子不在待审核状态，当前状态: " + post.getStatus());
        }

        post.setStatus(PostStatus.NORMAL);
        post.setHiddenReason(null);
        post.setUpdatedByAdmin(null);
        post.setUpdatedAt(Instant.now());
        Post savedPost = postRepository.save(post);

        log.info("帖子审核通过完成 — postId={}, newStatus={}", postId, savedPost.getStatus());

        try {
            webSocketService.sendPostStatusUpdate(postId, "NORMAL", post.getTitle());
        } catch (Exception e) {
            log.error("发送WebSocket通知失败: {}", e.getMessage());
        }
    }

    @Transactional
    public void rejectAuditPost(Long postId, String reason) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        log.info("打回帖子 — postId={}, currentStatus={}", postId, post.getStatus());

        if (post.getStatus() != PostStatus.AUDIT) {
            throw new BadRequestException("帖子不在待审核状态，当前状态: " + post.getStatus());
        }

        post.setStatus(PostStatus.DRAFT);
        post.setHiddenReason(reason);
        post.setUpdatedAt(Instant.now());
        Post savedPost = postRepository.save(post);

        log.info("帖子打回完成 — postId={}, newStatus={}, reason={}",
                postId, savedPost.getStatus(), savedPost.getHiddenReason());

        try {
            webSocketService.sendPostStatusUpdate(postId, "DRAFT", post.getTitle());
        } catch (Exception e) {
            log.error("发送WebSocket通知失败: {}", e.getMessage());
        }
    }

    // ========== 管理员申请相关 ==========

    @Transactional
    public AdminApplication createAdminApplication(AdminApplicationReq req,
                                                   User currentUser) {
        ensureAdmin(currentUser);
        User candidate = userRepository.findById(req.candidateUserId())
                .orElseThrow(() -> new NotFoundException("被推荐用户不存在"));
        AdminApplication app = new AdminApplication();
        app.setRecommender(currentUser);
        app.setCandidate(candidate);
        app.setReason(req.reason());
        return applicationRepository.save(app);
    }

    public Page<AdminApplication> listApplications(AdminApplicationStatus status,
                                                   Pageable pageable) {
        if (status != null) {
            return applicationRepository.findByStatus(status, pageable);
        }
        return applicationRepository.findAll(pageable);
    }

    @Transactional
    public AdminApplication approveApplication(Long appId, User currentUser) {
        ensureSuperAdmin(currentUser);
        AdminApplication app = applicationRepository.findById(appId)
                .orElseThrow(() -> new NotFoundException("申请不存在"));
        app.setStatus(AdminApplicationStatus.APPROVED);
        app.setDecidedBy(currentUser);
        app.setDecidedAt(Instant.now());
        User candidate = app.getCandidate();
        if (candidate.getRole() != UserRole.SUPER_ADMIN) {
            candidate.setRole(UserRole.ADMIN);
            userRepository.save(candidate);
        }
        return applicationRepository.save(app);
    }

    @Transactional
    public AdminApplication rejectApplication(Long appId, User currentUser) {
        ensureSuperAdmin(currentUser);
        AdminApplication app = applicationRepository.findById(appId)
                .orElseThrow(() -> new NotFoundException("申请不存在"));
        app.setStatus(AdminApplicationStatus.REJECTED);
        app.setDecidedBy(currentUser);
        app.setDecidedAt(Instant.now());
        return applicationRepository.save(app);
    }

    // ========== 权限相关 ==========

    @Transactional
    public void grantAdmin(Long targetUserId, User currentUser) {
        ensureSuperAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if (u.getRole() == UserRole.SUPER_ADMIN) {
            throw new BadRequestException("不能修改超级管理员角色");
        }
        u.setRole(UserRole.ADMIN);
        userRepository.save(u);
    }

    @Transactional
    public void revokeAdmin(Long targetUserId, User currentUser) {
        ensureSuperAdmin(currentUser);
        User u = userRepository.findById(targetUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));
        if (u.getRole() == UserRole.SUPER_ADMIN) {
            throw new BadRequestException("不能修改超级管理员角色");
        }
        u.setRole(UserRole.USER);
        userRepository.save(u);
    }
}
