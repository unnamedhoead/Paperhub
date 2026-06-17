package com.example.paperhub.admin.dto;

import java.util.List;

public record NoticeListResp(
        List<NoticeResp> notices,
        long total,
        int page,
        int pageSize
) {}
