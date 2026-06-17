package com.example.paperhub.report.dto;

import java.util.List;

/**
 * Paginated list of post items.
 */
public record PostListResponse(
        List<PostListItemResponse> posts,
        long total,
        int page,
        int pageSize
) {}
