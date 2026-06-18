package com.example.paperhub.report.dto;

import java.time.Instant;
import java.util.List;

/**
 * Response DTO for post detail with visibility and edit info.
 * Extracted from ReportPostService.PostDetailResponse inner class.
 */
public record PostDetailResponse(
        Long id,
        String title,
        String content,
        List<String> media,
        List<String> tags,
        Long authorId,
        String authorName,
        String status,
        String hiddenReason,
        boolean visible,
        boolean canEdit,
        String message,
        Instant createdAt,
        Instant updatedAt
) {}
