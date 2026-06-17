package com.example.paperhub.admin.dto;

import java.time.Instant;

public record AdminApplicationResp(
        Long id,
        SimpleUserInfo recommender,
        SimpleUserInfo candidate,
        String reason,
        String status,
        Instant createdAt,
        Instant decidedAt
) {}
