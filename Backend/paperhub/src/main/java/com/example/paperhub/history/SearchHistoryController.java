package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.history.dto.MessageResp;
import com.example.paperhub.history.dto.RecentKeywordsResp;
import com.example.paperhub.history.dto.RecordSearchHistoryReq;
import com.example.paperhub.history.dto.SearchHistoryListResp;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/search-history")
public class SearchHistoryController {

    private final SearchHistoryService searchHistoryService;

    public SearchHistoryController(SearchHistoryService searchHistoryService) {
        this.searchHistoryService = searchHistoryService;
    }

    /**
     * GET /search-history?limit=20
     * 返回当前用户最近的搜索历史列表。
     */
    @GetMapping
    public SearchHistoryListResp list(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(name = "limit", required = false) Integer limit
    ) {
        Long userId = requireUserId(currentUser);
        List<SearchHistory> history = searchHistoryService.getHistory(userId, limit);
        long total = searchHistoryService.getHistoryCount(userId);
        return SearchHistoryListResp.of(history, total);
    }

    /**
     * POST /search-history
     * body: { "keyword": "深度学习", "searchType": "keyword" }
     * 记录一次搜索历史。
     */
    @PostMapping
    public MessageResp record(
            @AuthenticationPrincipal User currentUser,
            @Valid @RequestBody RecordSearchHistoryReq req
    ) {
        Long userId = requireUserId(currentUser);
        searchHistoryService.recordSearch(userId, req.keyword(), req.searchTypeOrDefault());
        return MessageResp.ok();
    }

    /**
     * DELETE /search-history/{id}
     * 删除当前用户的一条搜索历史。
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteOne(
            @AuthenticationPrincipal User currentUser,
            @PathVariable("id") Long id
    ) {
        Long userId = requireUserId(currentUser);
        searchHistoryService.deleteOne(userId, id);
        return ResponseEntity.noContent().build();
    }

    /**
     * DELETE /search-history
     * 清空当前用户的所有搜索历史。
     */
    @DeleteMapping
    public ResponseEntity<Void> clearAll(
            @AuthenticationPrincipal User currentUser
    ) {
        Long userId = requireUserId(currentUser);
        searchHistoryService.clearAll(userId);
        return ResponseEntity.noContent().build();
    }

    /**
     * GET /search-history/recent-keywords?limit=50
     * 获取用户最近搜索的关键词（用于推荐算法）。
     */
    @GetMapping("/recent-keywords")
    public RecentKeywordsResp getRecentKeywords(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(name = "limit", defaultValue = "50") int limit
    ) {
        Long userId = requireUserId(currentUser);
        List<String> keywords = searchHistoryService.getRecentKeywords(userId, limit);
        return RecentKeywordsResp.of(keywords);
    }

    private Long requireUserId(User currentUser) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        return currentUser.getId();
    }
}
