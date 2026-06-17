package com.example.paperhub.history.dto;

import com.example.paperhub.history.BrowseHistory;

/**
 * 浏览历史单条记录的响应。
 *
 * <p>JSON 兼容性：字段名 {@code postId} / {@code title} / {@code viewedAt} 必须与前端
 * {@code BrowseHistoryService.getHistory} 读取的字段保持一致。viewedAt 为 ISO-8601 字符串。
 */
public record BrowseHistoryItemResp(
        Long postId,
        String title,
        String viewedAt
) {
    public static BrowseHistoryItemResp from(BrowseHistory h) {
        return new BrowseHistoryItemResp(
                h.getPost().getId(),
                h.getPostTitle(),
                h.getViewedAt().toString()
        );
    }
}
