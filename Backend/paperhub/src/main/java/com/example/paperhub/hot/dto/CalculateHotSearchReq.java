package com.example.paperhub.hot.dto;

/**
 * POST /hot-searches/calculate 请求体（可选）。
 *
 * <p>JSON 兼容性：旧实现接受 {@code {"force": true}}（boolean 或字符串）。这里用 Boolean，
 * Jackson 会自动把字符串 "true"/"false" 解析为布尔值。请求体允许整体缺省（{@code null}）。
 */
public record CalculateHotSearchReq(
        Boolean force
) {
    public boolean forceOrDefault() {
        return Boolean.TRUE.equals(force);
    }
}
