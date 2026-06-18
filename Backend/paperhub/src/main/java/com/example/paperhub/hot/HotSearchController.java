package com.example.paperhub.hot;

import com.example.paperhub.hot.dto.CalculateHotSearchReq;
import com.example.paperhub.hot.dto.CalculateHotSearchResp;
import com.example.paperhub.hot.dto.HotSearchDetailResp;
import com.example.paperhub.hot.dto.HotSearchListResp;
import com.example.paperhub.hot.dto.HotSearchStatsResp;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 热搜榜单API控制器
 *
 * 提供热搜榜单的查询接口，支持：
 * 1. 获取最新热搜榜单
 * 2. 获取热搜详情（历史趋势，占位实现）
 * 3. 手动触发热搜计算（管理员功能）
 */
@RestController
@RequestMapping("/hot-searches")
public class HotSearchController {

    private static final int MAX_HOT_SEARCH_LIMIT = 50;
    private static final int DEFAULT_HOT_SEARCH_LIMIT = 20;

    private final HotSearchService hotSearchService;

    public HotSearchController(HotSearchService hotSearchService) {
        this.hotSearchService = hotSearchService;
    }

    /**
     * GET /hot-searches?limit=20&type=keyword|tag|author
     * 获取最新的热搜榜单。limit 默认 20，最大 50；type 为可选的搜索类型筛选。
     */
    @GetMapping
    public HotSearchListResp getHotSearches(
            @RequestParam(name = "limit", required = false, defaultValue = "20") int limit,
            @RequestParam(name = "type", required = false) String searchType) {

        int effectiveLimit = limit;
        if (effectiveLimit <= 0) {
            effectiveLimit = DEFAULT_HOT_SEARCH_LIMIT;
        }
        if (effectiveLimit > MAX_HOT_SEARCH_LIMIT) {
            effectiveLimit = MAX_HOT_SEARCH_LIMIT;
        }

        List<HotSearch> hotSearches = hotSearchService.getLatestHotSearches(effectiveLimit);

        if (searchType != null && !searchType.trim().isEmpty()) {
            String finalSearchType = searchType.trim();
            hotSearches = hotSearches.stream()
                    .filter(hs -> finalSearchType.equals(hs.getSearchType()))
                    .toList();
        }

        return HotSearchListResp.of(hotSearches);
    }

    /**
     * GET /hot-searches/{keyword}
     * 获取指定关键词的热搜详情（历史趋势）。当前为占位实现。
     */
    @GetMapping("/{keyword}")
    public HotSearchDetailResp getHotSearchDetail(
            @PathVariable String keyword,
            @RequestParam(name = "searchType", required = false, defaultValue = "keyword") String searchType,
            @RequestParam(name = "limit", required = false, defaultValue = "10") int limit) {

        // TODO: 实现历史趋势查询（需要新增 Repository 方法查询指定关键词的历史排名）
        return HotSearchDetailResp.placeholder(keyword, searchType);
    }

    /**
     * POST /hot-searches/calculate
     * 手动触发热搜计算（管理员功能）。请求体可选：{ "force": true }。
     * 计算失败时抛出异常，由 GlobalExceptionHandler 统一返回错误信封。
     */
    @PostMapping("/calculate")
    public CalculateHotSearchResp calculateHotSearches(
            @RequestBody(required = false) CalculateHotSearchReq req) {

        boolean force = req != null && req.forceOrDefault();
        hotSearchService.calculateAndUpdateHotSearches();
        return CalculateHotSearchResp.done(force);
    }

    /**
     * GET /hot-searches/stats
     * 获取热搜统计信息（管理员功能）。当前为占位实现。
     */
    @GetMapping("/stats")
    public HotSearchStatsResp getHotSearchStats() {
        // TODO: 实现统计信息查询
        return HotSearchStatsResp.placeholder();
    }
}
