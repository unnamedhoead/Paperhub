package com.example.paperhub.hot.dto;

import java.time.Instant;

/**
 * GET /hot-searches/{keyword} 响应（历史趋势功能仍为占位实现）。
 *
 * <p>JSON 兼容性：保留旧字段 {@code keyword} / {@code searchType} / {@code message} / {@code timestamp}。
 */
public record HotSearchDetailResp(
        String keyword,
        String searchType,
        String message,
        String timestamp
) {
    public static HotSearchDetailResp placeholder(String keyword, String searchType) {
        return new HotSearchDetailResp(keyword, searchType, "历史趋势功能待实现", Instant.now().toString());
    }
}
