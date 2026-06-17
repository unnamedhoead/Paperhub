package com.example.paperhub.report.dto;

import java.time.Instant;

/**
 * A single post item in the admin audit list.
 */
public record PostListItemResponse(
        Long id,
        String title,
        Long authorId,
        String authorName,
        String authorEmail,
        String status,
        String hiddenReason,
        Instant createdAt,
        Instant updatedAt
) {}
