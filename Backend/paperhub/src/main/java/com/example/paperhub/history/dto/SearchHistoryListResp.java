package com.example.paperhub.history.dto;

import com.example.paperhub.history.SearchHistory;

import java.time.Instant;
import java.util.List;

/**
 * GET /search-history 响应体。
 *
 * <p>JSON 兼容性：前端直接读取顶层 {@code body['items']}，因此该 DTO 即为响应根对象。
 * 字段 {@code items} / {@code count} / {@code total} / {@code timestamp} 与旧 Map 响应一致。
 */
public record SearchHistoryListResp(
        List<SearchHistoryItemResp> items,
        int count,
        long total,
        String timestamp
) {
    public static SearchHistoryListResp of(List<SearchHistory> history, long total) {
        List<SearchHistoryItemResp> items = history.stream()
                .map(SearchHistoryItemResp::from)
                .toList();
        return new SearchHistoryListResp(items, items.size(), total, Instant.now().toString());
    }
}
