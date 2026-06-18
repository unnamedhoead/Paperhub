package com.example.paperhub.admin.dto;

import java.util.List;

public record AdminApplicationListResp(
        List<AdminApplicationResp> applications,
        long total,
        int page,
        int pageSize
) {}
