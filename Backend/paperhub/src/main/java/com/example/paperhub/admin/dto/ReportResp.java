package com.example.paperhub.admin.dto;

import java.time.Instant;

public record ReportResp(
        Long id,
        SimpleUserInfo reporter,
        String targetType,
        SimpleUserInfo reportedUser,
        Long postId,
        Long commentId,
        String reason,
        String status,
        String resolution,
        Instant createdAt
) {}
