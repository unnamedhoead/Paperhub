package com.example.paperhub.hot.dto;

import java.time.Instant;

/**
 * GET /hot-searches/stats 响应（统计功能仍为占位实现）。
 *
 * <p>JSON 兼容性：保留旧字段 {@code message} / {@code timestamp}。
 */
public record HotSearchStatsResp(
        String message,
        String timestamp
) {
    public static HotSearchStatsResp placeholder() {
        return new HotSearchStatsResp("统计功能待实现", Instant.now().toString());
    }
}
