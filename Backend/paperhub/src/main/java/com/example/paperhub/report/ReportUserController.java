package com.example.paperhub.report;

import com.example.paperhub.auth.User;
import com.example.paperhub.report.dto.OperationResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * User reporting controller (report other users).
 * Uses ReportUserService for all business logic — no entity construction in controller.
 */
@RestController
@RequestMapping("/api/report")
@CrossOrigin(origins = "*")
public class ReportUserController {

    private final ReportUserService reportUserService;

    public ReportUserController(ReportUserService reportUserService) {
        this.reportUserService = reportUserService;
    }

    @PostMapping("/user/{userId}")
    public ResponseEntity<?> reportUser(
            @PathVariable Long userId,
            @Valid @RequestBody ReportUserRequest request,
            @AuthenticationPrincipal User currentUser) {

        if (currentUser == null) {
            return ResponseEntity.status(401).body(
                    new OperationResponse(false, "用户未登录", null)
            );
        }

        try {
            reportUserService.reportUser(userId, request.reason(), currentUser);
            return ResponseEntity.ok(new OperationResponse(true, "举报成功", null));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(
                    new OperationResponse(false, e.getMessage(), null)
            );
        }
    }

    /**
     * Request DTO for user reporting.
     */
    public record ReportUserRequest(
            @NotBlank(message = "举报原因不能为空")
            String reason
    ) {}
}
