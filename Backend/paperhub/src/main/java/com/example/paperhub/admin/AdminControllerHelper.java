package com.example.paperhub.admin;

import com.example.paperhub.admin.dto.AdminApplicationResp;
import com.example.paperhub.admin.dto.NoticeResp;
import com.example.paperhub.admin.dto.ReportResp;
import com.example.paperhub.admin.dto.SimpleUserInfo;
import com.example.paperhub.auth.User;

/**
 * Shared mapping helpers for admin controllers.
 * Pure data-mapping functions, not business logic.
 */
final class AdminControllerHelper {

    private AdminControllerHelper() {}

    static SimpleUserInfo toSimpleUser(User u) {
        if (u == null) return null;
        return new SimpleUserInfo(
                u.getId(),
                u.getName(),
                u.getEmail(),
                u.getRole() != null ? u.getRole().name() : "USER",
                u.getStatus() != null ? u.getStatus().name() : "NORMAL"
        );
    }

    static NoticeResp toNoticeResp(AdminNotice n) {
        return new NoticeResp(
                n.getId(),
                n.getTitle(),
                n.getContent(),
                n.getAttachments(),
                n.isPublished(),
                n.getCreatedAt(),
                n.getUpdatedAt()
        );
    }

    static ReportResp toReportResp(AdminReport r) {
        Long postId = r.getPost() != null ? r.getPost().getId() : null;
        Long commentId = r.getComment() != null ? r.getComment().getId() : null;
        return new ReportResp(
                r.getId(),
                toSimpleUser(r.getReporter()),
                r.getTargetType() != null ? r.getTargetType().name() : null,
                toSimpleUser(r.getReportedUser()),
                postId,
                commentId,
                r.getReason(),
                r.getStatus() != null ? r.getStatus().name() : null,
                r.getResolution(),
                r.getCreatedAt()
        );
    }

    static AdminApplicationResp toApplicationResp(AdminApplication app) {
        return new AdminApplicationResp(
                app.getId(),
                toSimpleUser(app.getRecommender()),
                toSimpleUser(app.getCandidate()),
                app.getReason(),
                app.getStatus() != null ? app.getStatus().name() : null,
                app.getCreatedAt(),
                app.getDecidedAt()
        );
    }
}
