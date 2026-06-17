package com.example.paperhub.admin.dto;

import java.time.Instant;

public record NoticeResp(
        Long id,
        String title,
        String content,
        String attachments,
        boolean published,
        Instant createdAt,
        Instant updatedAt
) {}
