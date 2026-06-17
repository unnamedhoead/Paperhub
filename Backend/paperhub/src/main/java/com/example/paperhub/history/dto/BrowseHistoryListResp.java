package com.example.paperhub.history.dto;

import com.example.paperhub.history.BrowseHistory;

import java.time.Instant;
import java.util.List;

/**
 * GET /browse-history 响应体。
 *
 * <p>JSON 兼容性：前端直接读取顶层 {@code body['items']}，因此该 DTO 即为响应根对象，
 * 不再包裹进统一的 {@code ApiResponse} 信封（成功路径保持扁平结构，与前端现有解析一致）。
 * 字段 {@code items} / {@code count} / {@code timestamp} 与旧的 Map 响应一一对应。
 */
public record BrowseHistoryListResp(
        List<BrowseHistoryItemResp> items,
        int count,
        String timestamp
) {
    public static BrowseHistoryListResp of(List<BrowseHistory> history) {
        List<BrowseHistoryItemResp> items = history.stream()
                .map(BrowseHistoryItemResp::from)
                .toList();
        return new BrowseHistoryListResp(items, items.size(), Instant.now().toString());
    }
}
