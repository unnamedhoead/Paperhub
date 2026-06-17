package com.example.paperhub.hot.dto;

import com.example.paperhub.hot.HotSearch;

import java.time.Instant;
import java.util.List;

/**
 * GET /hot-searches 响应体。
 *
 * <p>JSON 兼容性：前端 {@code search_screen.dart} 直接读取顶层 {@code body['items']}，
 * 因此该 DTO 即为响应根对象。字段 {@code items} / {@code count} / {@code periodEnd} /
 * {@code timestamp} 与旧 Map 响应一致；{@code periodEnd} 取（筛选后）首条记录的 periodEnd，
 * 列表为空时回退为当前时间。
 */
public record HotSearchListResp(
        List<HotSearchItemResp> items,
        int count,
        String periodEnd,
        String timestamp
) {
    public static HotSearchListResp of(List<HotSearch> hotSearches) {
        List<HotSearchItemResp> items = hotSearches.stream()
                .map(HotSearchItemResp::from)
                .toList();
        String periodEnd = hotSearches.isEmpty()
                ? Instant.now().toString()
                : hotSearches.get(0).getPeriodEnd().toString();
        return new HotSearchListResp(items, items.size(), periodEnd, Instant.now().toString());
    }
}
