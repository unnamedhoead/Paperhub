package com.example.paperhub.admin;

import com.example.paperhub.admin.dto.*;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.auth.UserStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Admin user management: search, ban/unban, mute/unmute, audit.
 */
@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = "*")
public class AdminUserController {

    private final AdminService adminService;

    public AdminUserController(AdminService adminService) {
        this.adminService = adminService;
    }

    @GetMapping("/users")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> searchUsers(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        Pageable pageable = PageRequest.of(page, pageSize);
        Page<User> userPage = adminService.searchUsers(q, status, pageable);

        var list = userPage.getContent().stream().map(u -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", u.getId());
            m.put("email", u.getEmail());
            m.put("name", u.getName());
            m.put("role", u.getRole() != null ? u.getRole().name() : UserRole.USER.name());
            m.put("status", u.getStatus() != null ? u.getStatus().name() : "NORMAL");
            return m;
        }).toList();

        return ResponseEntity.ok(Map.of(
                "users", list,
                "total", userPage.getTotalElements(),
                "page", page,
                "pageSize", pageSize
        ));
    }

    @PostMapping("/users/{userId}/ban")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> banUser(@AuthenticationPrincipal User currentUser,
                                     @PathVariable Long userId) {
        adminService.banUser(userId, currentUser);
        return ResponseEntity.ok(Map.of("message", "用户已封禁"));
    }

    @PostMapping("/users/{userId}/unban")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> unbanUser(@AuthenticationPrincipal User currentUser,
                                       @PathVariable Long userId) {
        adminService.unbanUser(userId, currentUser);
        return ResponseEntity.ok(Map.of("message", "已解除封禁"));
    }

    @PostMapping("/users/{userId}/mute")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> muteUser(@AuthenticationPrincipal User currentUser,
                                      @PathVariable Long userId,
                                      @RequestParam int duration,
                                      @RequestParam String unit) {
        adminService.muteUser(userId, duration, unit, currentUser);
        return ResponseEntity.ok(Map.of("message", "用户已禁言"));
    }

    @PostMapping("/users/{userId}/unmute")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> unmuteUser(@AuthenticationPrincipal User currentUser,
                                        @PathVariable Long userId) {
        adminService.unmuteUser(userId, currentUser);
        return ResponseEntity.ok(Map.of("message", "已解除禁言"));
    }

    @GetMapping("/users/audit-list")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> getAuditUsers(@AuthenticationPrincipal User currentUser) {
        List<User> auditUsers = adminService.getAuditUsers();
        var list = auditUsers.stream().map(u -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", u.getId());
            m.put("email", u.getEmail());
            m.put("name", u.getName());
            m.put("role", u.getRole() != null ? u.getRole().name() : UserRole.USER.name());
            m.put("status", u.getStatus() != null ? u.getStatus().name() : "NORMAL");
            return m;
        }).toList();
        return ResponseEntity.ok(Map.of("users", list));
    }

    @PostMapping("/users/{userId}/approve")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> approveUser(@AuthenticationPrincipal User currentUser,
                                         @PathVariable Long userId) {
        adminService.approveUser(userId, currentUser);
        return ResponseEntity.ok(Map.of("message", "审核通过，用户已恢复正常"));
    }

    @PostMapping("/users/{userId}/reject")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> rejectUser(@AuthenticationPrincipal User currentUser,
                                        @PathVariable Long userId,
                                        @RequestBody Map<String, String> body) {
        String action = body.getOrDefault("action", "BAN");
        String reason = body.getOrDefault("reason", "");
        adminService.rejectUser(userId, action, reason, currentUser);
        return ResponseEntity.ok(Map.of("message", "审核拒绝，已执行处理"));
    }
}
