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
 * Admin notice management: CRUD.
 */
@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = "*")
public class AdminNoticeController {

    private final AdminService adminService;

    public AdminNoticeController(AdminService adminService) {
        this.adminService = adminService;
    }

    @GetMapping("/notices")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<NoticeListResp> listNotices(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        Page<AdminNotice> noticePage = adminService.listNotices(q, PageRequest.of(page, pageSize));
        var list = noticePage.getContent().stream()
                .map(AdminControllerHelper::toNoticeResp)
                .toList();
        return ResponseEntity.ok(new NoticeListResp(
                list,
                noticePage.getTotalElements(),
                page,
                pageSize
        ));
    }

    @PostMapping("/notices")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<NoticeResp> createNotice(@AuthenticationPrincipal User currentUser,
                                                    @Valid @RequestBody NoticeReq req) {
        AdminNotice n = adminService.createNotice(req);
        return ResponseEntity.ok(AdminControllerHelper.toNoticeResp(n));
    }

    @PutMapping("/notices/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<NoticeResp> updateNotice(@AuthenticationPrincipal User currentUser,
                                                    @PathVariable Long id,
                                                    @Valid @RequestBody NoticeReq req) {
        AdminNotice n = adminService.updateNotice(id, req);
        return ResponseEntity.ok(AdminControllerHelper.toNoticeResp(n));
    }

    @DeleteMapping("/notices/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> deleteNotice(@AuthenticationPrincipal User currentUser,
                                          @PathVariable Long id) {
        adminService.deleteNotice(id);
        return ResponseEntity.ok(Map.of("message", "删除成功"));
    }
}
