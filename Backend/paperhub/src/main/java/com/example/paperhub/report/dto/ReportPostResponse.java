package com.example.paperhub.report.dto;

import java.time.Instant;

/**
 * Response DTO after a user reports a post.
 */
public record ReportPostResponse(
        Long id,
        Long reporterId,
        String reporterName,
        Long postId,
        String postTitle,
        String description,
        String status,
        Instant reportTime,
        String message
) {}
