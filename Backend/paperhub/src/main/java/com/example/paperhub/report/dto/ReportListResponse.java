package com.example.paperhub.report.dto;

import java.util.List;

/**
 * Paginated list of report items.
 */
public record ReportListResponse(
        List<ReportListItemResponse> reports,
        long total,
        int page,
        int pageSize
) {}
