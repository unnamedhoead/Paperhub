package com.example.paperhub.hot.dto;

import com.example.paperhub.hot.HotSearch;

/**
 * 热搜榜单单条记录的响应。
 *
 * <p>JSON 兼容性：字段名必须与前端 {@code search_screen.dart} 读取的字段一致：
 * {@code rank} / {@code keyword} / {@code searchType} / {@code heat} / {@code tag}。
 * 其中 {@code heat} 来源于 {@link HotSearch#getHeatScore()}（注意字段名是 heat 而非 heatScore）。
 * 另外保留 {@code searchCount} / {@code uniqueUsers} / {@code growthRate} /
 * {@code periodStart} / {@code periodEnd} 以与旧 Map 响应完全对齐。
 */
public record HotSearchItemResp(
        Integer rank,
        String keyword,
        String searchType,
        Double heat,
        String tag,
        Long searchCount,
        Long uniqueUsers,
        Double growthRate,
        String periodStart,
        String periodEnd
) {
    public static HotSearchItemResp from(HotSearch hs) {
        return new HotSearchItemResp(
                hs.getRank(),
                hs.getKeyword(),
                hs.getSearchType(),
                hs.getHeatScore(),
                hs.getTag(),
                hs.getSearchCount(),
                hs.getUniqueUsers(),
                hs.getGrowthRate(),
                hs.getPeriodStart().toString(),
                hs.getPeriodEnd().toString()
        );
    }
}
