package com.example.paperhub.user.dto;

import java.util.List;

/**
 * 个人主页展示响应。
 */
public record ProfileResp(
        Long id,
        String email,
        String role,
        String status,
        String statusMessage,
        String displayName,
        String avatar,
        String backgroundImage,
        String bio,
        List<String> researchDirections,
        int followingCount,
        int followersCount,
        int postsCount,
        int favoritesCount,
        int favoritesReceivedCount,
        int likesCount,
        Boolean isFollowing,
        Boolean isFollower,
        // 隐私设置（用于前端根据被查看用户的设置控制展示）
        Boolean hideFollowing,
        Boolean hideFollowers,
        Boolean publicFavorites
) {}
