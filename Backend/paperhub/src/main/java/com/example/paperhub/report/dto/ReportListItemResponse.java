package com.example.paperhub.report.dto;

import java.time.Instant;

/**
 * A single report item in the admin report list.
 */
public record ReportListItemResponse(
        Long id,
        Long reporterId,
        String reporterName,
        String reporterEmail,
        Long postId,
        String postTitle,
        Long postAuthorId,
        String postAuthorName,
        String description,
        String status,
        Instant reportTime,
        Long adminId,
        String adminName,
        Instant handleTime,
        String handleResult,
        String postStatusAfter
) {}
