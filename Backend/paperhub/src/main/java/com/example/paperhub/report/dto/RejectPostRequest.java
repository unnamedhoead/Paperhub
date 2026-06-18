package com.example.paperhub.report.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Admin request to reject a post audit.
 */
public record RejectPostRequest(
        @NotBlank(message = "拒绝原因不能为空")
        String reason
) {}
