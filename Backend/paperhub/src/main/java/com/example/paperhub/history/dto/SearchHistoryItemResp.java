package com.example.paperhub.history.dto;

import com.example.paperhub.history.SearchHistory;

/**
 * 搜索历史单条记录的响应。
 *
 * <p>JSON 兼容性：字段 {@code id} / {@code keyword} / {@code searchType} /
 * {@code searchCount} / {@code createdAt} / {@code updatedAt} 与前端
 * {@code SearchHistoryItem.fromCloudData} 读取的字段保持一致；时间字段为 ISO-8601 字符串。
 */
public record SearchHistoryItemResp(
        Long id,
        String keyword,
        String searchType,
        Integer searchCount,
        String createdAt,
        String updatedAt
) {
    public static SearchHistoryItemResp from(SearchHistory h) {
        return new SearchHistoryItemResp(
                h.getId(),
                h.getKeyword(),
                h.getSearchType(),
                h.getSearchCount(),
                h.getCreatedAt().toString(),
                h.getUpdatedAt().toString()
        );
    }
}
