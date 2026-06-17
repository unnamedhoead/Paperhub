package com.example.paperhub.admin.dto;

import java.util.List;

public record ReportListResp(
        List<ReportResp> reports,
        long total,
        int page,
        int pageSize
) {}
