package com.example.paperhub.history.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * POST /search-history 请求体。
 *
 * <p>JSON 兼容性：前端 {@code ApiService.addSearchHistory} 发送
 * {@code {"keyword": "...", "searchType": "keyword|tag|author"}}。
 *
 * <p>校验语义沿用旧 controller：
 * <ul>
 *   <li>keyword 必填且非空白；长度上限对齐数据库列（512）。</li>
 *   <li>searchType 可缺省（{@code null}），由 controller 回退为 "keyword"；
 *       若显式传值，则必须是 keyword/tag/author 之一（{@code @Pattern} 对 null 视为合法）。</li>
 * </ul>
 */
public record RecordSearchHistoryReq(
        @NotBlank(message = "keyword 不能为空")
        @Size(max = 512, message = "keyword 长度不能超过 512")
        String keyword,

        @Pattern(regexp = "keyword|tag|author", message = "searchType 必须为 'keyword', 'tag' 或 'author'")
        String searchType
) {
    /** 缺省时回退为 "keyword"，保持旧 controller 行为。 */
    public String searchTypeOrDefault() {
        return (searchType == null || searchType.isBlank()) ? "keyword" : searchType;
    }
}
