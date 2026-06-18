package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.history.dto.BrowseHistoryListResp;
import com.example.paperhub.history.dto.MessageResp;
import com.example.paperhub.history.dto.RecordBrowseHistoryReq;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/browse-history")
public class BrowseHistoryController {

    private final BrowseHistoryService browseHistoryService;

    public BrowseHistoryController(BrowseHistoryService browseHistoryService) {
        this.browseHistoryService = browseHistoryService;
    }

    /**
     * GET /browse-history?limit=50
     * 返回当前用户最近浏览的帖子列表。
     */
    @GetMapping
    public BrowseHistoryListResp list(
            @AuthenticationPrincipal User currentUser,
            @RequestParam(name = "limit", defaultValue = "50") int limit
    ) {
        Long userId = requireUserId(currentUser);
        List<BrowseHistory> history = browseHistoryService.getHistory(userId, limit);
        return BrowseHistoryListResp.of(history);
    }

    /**
     * POST /browse-history
     * body: { "postId": 123, "title": "..." }
     * 显式记录一次浏览（前端通常在详情页内已记录，此接口作为补充）。
     */
    @PostMapping
    public MessageResp record(
            @AuthenticationPrincipal User currentUser,
            @Valid @RequestBody RecordBrowseHistoryReq req
    ) {
        Long userId = requireUserId(currentUser);
        browseHistoryService.recordHistory(userId, req.postIdAsLong(), req.title());
        return MessageResp.ok();
    }

    /**
     * DELETE /browse-history/{postId}
     * 删除当前用户针对某一帖子的浏览记录。
     */
    @DeleteMapping("/{postId}")
    public ResponseEntity<Void> deleteOne(
            @AuthenticationPrincipal User currentUser,
            @PathVariable("postId") Long postId
    ) {
        Long userId = requireUserId(currentUser);
        browseHistoryService.deleteOne(userId, postId);
        return ResponseEntity.noContent().build();
    }

    /**
     * DELETE /browse-history
     * 清空当前用户的所有浏览历史。
     */
    @DeleteMapping
    public ResponseEntity<Void> clearAll(
            @AuthenticationPrincipal User currentUser
    ) {
        Long userId = requireUserId(currentUser);
        browseHistoryService.clearAll(userId);
        return ResponseEntity.noContent().build();
    }

    private Long requireUserId(User currentUser) {
        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        return currentUser.getId();
    }
}
