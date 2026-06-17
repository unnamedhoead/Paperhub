package com.example.paperhub.user.dto;

/**
 * 更新隐私设置请求体。
 */
public record UpdatePrivacySettingsReq(
        Boolean hideFollowing,
        Boolean hideFollowers,
        Boolean publicFavorites
) {}
