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

import java.util.Map;

/**
 * Admin permission and application management.
 * Super-admin operations: grant/revoke admin role, approve/reject applications.
 * Admin operations: create applications.
 */
@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = "*")
public class AdminPermissionController {

    private final AdminService adminService;

    public AdminPermissionController(AdminService adminService) {
        this.adminService = adminService;
    }

    @PostMapping("/permissions/{userId}/grant-admin")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> grantAdmin(@AuthenticationPrincipal User currentUser,
                                        @PathVariable Long userId) {
        adminService.grantAdmin(userId, currentUser);
        return ResponseEntity.ok(Map.of("message", "已授予管理员权限"));
    }

    @PostMapping("/permissions/{userId}/revoke-admin")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<?> revokeAdmin(@AuthenticationPrincipal User currentUser,
                                         @PathVariable Long userId) {
        adminService.revokeAdmin(userId, currentUser);
        return ResponseEntity.ok(Map.of("message", "已收回管理员权限"));
    }

    @PostMapping("/applications")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<AdminApplicationResp> createApplication(
            @AuthenticationPrincipal User currentUser,
            @Valid @RequestBody AdminApplicationReq req) {
        AdminApplication app = adminService.createAdminApplication(req, currentUser);
        return ResponseEntity.ok(AdminControllerHelper.toApplicationResp(app));
    }

    @GetMapping("/applications")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<AdminApplicationListResp> listApplications(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) AdminApplicationStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        Page<AdminApplication> applicationPage =
                adminService.listApplications(status, PageRequest.of(page, pageSize));
        var list = applicationPage.getContent().stream()
                .map(AdminControllerHelper::toApplicationResp)
                .toList();
        return ResponseEntity.ok(new AdminApplicationListResp(
                list,
                applicationPage.getTotalElements(),
                page,
                pageSize
        ));
    }

    @PostMapping("/applications/{id}/approve")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<AdminApplicationResp> approveApplication(
            @AuthenticationPrincipal User currentUser,
            @PathVariable Long id) {
        AdminApplication app = adminService.approveApplication(id, currentUser);
        return ResponseEntity.ok(AdminControllerHelper.toApplicationResp(app));
    }

    @PostMapping("/applications/{id}/reject")
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<AdminApplicationResp> rejectApplication(
            @AuthenticationPrincipal User currentUser,
            @PathVariable Long id) {
        AdminApplication app = adminService.rejectApplication(id, currentUser);
        return ResponseEntity.ok(AdminControllerHelper.toApplicationResp(app));
    }
}
