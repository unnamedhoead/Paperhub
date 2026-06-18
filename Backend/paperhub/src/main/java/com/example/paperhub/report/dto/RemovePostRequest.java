package com.example.paperhub.report.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * Admin request to remove (hide) a reported post.
 */
public record RemovePostRequest(
        @NotBlank(message = "下架原因不能为空")
        String reason
) {}
