package com.example.paperhub.user.dto;

import java.util.List;

/**
 * 用户列表响应。
 */
public record UserListResp(
        List<ProfileResp> users,
        long total,
        int page,
        int pageSize
) {}
