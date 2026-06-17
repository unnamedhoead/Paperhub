package com.example.paperhub.report;

import com.example.paperhub.admin.AdminReport;
import com.example.paperhub.admin.AdminReportRepository;
import com.example.paperhub.admin.ReportStatus;
import com.example.paperhub.admin.ReportTargetType;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.NotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Service for user reporting (targeting other users).
 * Extracted from ReportUserController to enforce proper layering.
 */
@Service
public class ReportUserService {

    private final AdminReportRepository reportRepository;
    private final UserRepository userRepository;

    public ReportUserService(AdminReportRepository reportRepository,
                             UserRepository userRepository) {
        this.reportRepository = reportRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public void reportUser(Long reportedUserId, String reason, User currentUser) {
        if (currentUser == null) {
            throw new BadRequestException("用户未登录");
        }

        User reportedUser = userRepository.findById(reportedUserId)
                .orElseThrow(() -> new NotFoundException("用户不存在"));

        if (reportedUser.getRole() == UserRole.ADMIN || reportedUser.getRole() == UserRole.SUPER_ADMIN) {
            throw new BadRequestException("不能举报管理员");
        }

        if (reportedUser.getId().equals(currentUser.getId())) {
            throw new BadRequestException("不能举报自己");
        }

        if (reportRepository.existsByReporterAndReportedUser(currentUser, reportedUser)) {
            throw new BadRequestException("您已经举报过该用户");
        }

        AdminReport report = new AdminReport();
        report.setReporter(currentUser);
        report.setReportedUser(reportedUser);
        report.setTargetType(ReportTargetType.USER);
        report.setReason(reason);
        report.setStatus(ReportStatus.PENDING);
        report.setCreatedAt(Instant.now());
        report.setUpdatedAt(Instant.now());

        reportRepository.save(report);

        // Set reported user to AUDIT status
        reportedUser.setStatus(UserStatus.AUDIT);
        userRepository.save(reportedUser);
    }
}
