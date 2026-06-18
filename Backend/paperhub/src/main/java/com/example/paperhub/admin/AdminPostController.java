package com.example.paperhub.admin;

import com.example.paperhub.auth.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * Admin post management: hide, search, approve/reject audit.
 */
@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = "*")
public class AdminPostController {

    private final AdminService adminService;

    public AdminPostController(AdminService adminService) {
        this.adminService = adminService;
    }

    @PostMapping("/posts/{postId}/hide")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> hidePost(@AuthenticationPrincipal User currentUser,
                                      @PathVariable Long postId) {
        adminService.hidePost(postId, currentUser);
        return ResponseEntity.ok(Map.of("message", "帖子已下架"));
    }

    @GetMapping("/posts")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> searchPosts(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String author,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int pageSize) {
        Pageable pageable = PageRequest.of(page, pageSize, Sort.by(Sort.Direction.DESC, "createdAt"));
        Page<com.example.paperhub.post.Post> postPage = adminService.searchPosts(q, author, pageable);

        var list = postPage.getContent().stream().map(p -> {
            Map<String, Object> m = new HashMap<>();
            m.put("id", p.getId());
            m.put("title", p.getTitle());
            m.put("authorId", p.getAuthor() != null ? p.getAuthor().getId() : null);
            m.put("authorName", p.getAuthor() != null ? p.getAuthor().getName() : null);
            m.put("authorEmail", p.getAuthor() != null ? p.getAuthor().getEmail() : null);
            m.put("status", p.getStatus() != null ? p.getStatus().name() : null);
            m.put("createdAt", p.getCreatedAt());
            return m;
        }).toList();

        return ResponseEntity.ok(Map.of(
                "posts", list,
                "total", postPage.getTotalElements(),
                "page", page,
                "pageSize", pageSize
        ));
    }

    @PostMapping("/post/{postId}/approve-audit")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> approveAuditPost(@AuthenticationPrincipal User currentUser,
                                              @PathVariable Long postId) {
        adminService.approveAuditPost(postId);
        return ResponseEntity.ok(Map.of("message", "审核通过"));
    }

    @PostMapping("/post/{postId}/reject-audit")
    @PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
    public ResponseEntity<?> rejectAuditPost(@AuthenticationPrincipal User currentUser,
                                             @PathVariable Long postId,
                                             @RequestBody Map<String, String> body) {
        String reason = body.getOrDefault("reason", "不符合发布要求");
        adminService.rejectAuditPost(postId, reason);
        return ResponseEntity.ok(Map.of("message", "已打回草稿"));
    }
}
