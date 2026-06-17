package com.example.paperhub.hot.dto;

import java.time.Instant;

/**
 * POST /hot-searches/calculate 成功响应。
 *
 * <p>JSON 兼容性：保留旧字段 {@code message} / {@code timestamp} / {@code force}。
 * 失败不再就地返回 500 Map，而是抛异常交由 {@code GlobalExceptionHandler} 统一处理
 * （该端点前端未调用，仅管理用途）。
 */
public record CalculateHotSearchResp(
        String message,
        String timestamp,
        boolean force
) {
    public static CalculateHotSearchResp done(boolean force) {
        return new CalculateHotSearchResp("热搜计算完成", Instant.now().toString(), force);
    }
}
