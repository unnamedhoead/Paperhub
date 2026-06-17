package com.example.paperhub.history.dto;

import java.time.Instant;
import java.util.List;

/**
 * GET /search-history/recent-keywords 响应体。
 *
 * <p>JSON 兼容性：字段 {@code keywords} / {@code count} / {@code timestamp} 与旧 Map 响应一致。
 */
public record RecentKeywordsResp(
        List<String> keywords,
        int count,
        String timestamp
) {
    public static RecentKeywordsResp of(List<String> keywords) {
        return new RecentKeywordsResp(keywords, keywords.size(), Instant.now().toString());
    }
}
