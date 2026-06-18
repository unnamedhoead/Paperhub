package com.example.paperhub.user.dto;

/**
 * 获取/更新隐私设置的响应。
 */
public record PrivacySettingsResp(
        Boolean hideFollowing,
        Boolean hideFollowers,
        Boolean publicFavorites
) {}
