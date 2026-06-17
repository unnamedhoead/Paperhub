package com.example.paperhub.admin;

import com.example.paperhub.admin.dto.*;
import com.example.paperhub.auth.User;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * Admin report handling.
 */
@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = "*")
public class AdminReportController {

    private final AdminService adminService;

    public AdminReportController(AdminService adminService) {
        this.adminService = adminService;
    }

    @GetMapping("/reports")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<ReportListResp> listReports(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) ReportStatus status,
            @RequestParam(required = false) ReportTargetType targetType,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        Page<AdminReport> reportPage = adminService.listReports(q, status, targetType,
                PageRequest.of(page, pageSize));
        var list = reportPage.getContent().stream()
                .map(AdminControllerHelper::toReportResp)
                .toList();
        return ResponseEntity.ok(new ReportListResp(
                list,
                reportPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    @PostMapping("/reports/{id}/handle")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<ReportResp> handleReport(@AuthenticationPrincipal User currentUser,
                                                   @PathVariable Long id,
                                                   @Valid @RequestBody HandleReportReq req) {
        AdminReport r = adminService.handleReport(id, req.action(), req.resolutionNote(), currentUser);
        return ResponseEntity.ok(AdminControllerHelper.toReportResp(r));
    }
}
