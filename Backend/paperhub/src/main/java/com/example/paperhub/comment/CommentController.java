package com.example.paperhub.comment;

import com.example.paperhub.auth.User;
import com.example.paperhub.comment.dto.CommentDtos;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.like.LikeService;
import com.example.paperhub.websocket.WebSocketService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/posts/{postId}/comments")
public class CommentController {
    private static final Logger log = LoggerFactory.getLogger(CommentController.class);

    private final CommentService commentService;
    private final LikeService likeService;
    private final WebSocketService webSocketService;
    private final com.example.paperhub.auth.UserRepository userRepository;

    public CommentController(CommentService commentService, LikeService likeService, WebSocketService webSocketService, com.example.paperhub.auth.UserRepository userRepository) {
        this.commentService = commentService;
        this.likeService = likeService;
        this.webSocketService = webSocketService;
        this.userRepository = userRepository;
    }

    /**
     * 获取评论列表
     * GET /posts/{postId}/comments?page=1&pageSize=20&sort=time
     */
    @GetMapping
    public ResponseEntity<CommentDtos.CommentListResp> getComments(
            @PathVariable Long postId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int pageSize,
            @RequestParam(defaultValue = "time") String sort,
            @AuthenticationPrincipal User user) {

        Page<Comment> commentPage = commentService.getComments(postId, page, pageSize, sort);
        Long userId = user != null ? user.getId() : null;

        List<CommentDtos.CommentResp> comments = commentPage.getContent().stream()
            .map(comment -> convertToCommentResp(comment, userId))
            .collect(Collectors.toList());

        return ResponseEntity.ok(new CommentDtos.CommentListResp(
            comments,
            commentPage.getTotalElements(),
            page,
            pageSize
        ));
    }

    /**
     * 创建评论
     * POST /posts/{postId}/comments
     */
    @PostMapping
    public ResponseEntity<CommentDtos.CommentResp> createComment(
            @PathVariable Long postId,
            @Valid @RequestBody CommentDtos.CreateCommentReq req,
            @AuthenticationPrincipal User user) {

        log.debug("创建评论: postId={}, userId={}, parentId={}, replyToId={}",
                postId, user != null ? user.getId() : null, req.parentId(), req.replyToId());

        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }

        try {
            List<Long> mentionIds = req.mentionIds() != null ? req.mentionIds() : List.of();
            Comment comment = commentService.createComment(
                postId,
                req.content(),
                user,
                req.parentId(),
                req.replyToId(),
                mentionIds
            );

            log.debug("评论创建成功: commentId={}", comment.getId());

            // 加载子回复
            List<Comment> replies = commentService.getReplies(comment.getId());

            CommentDtos.CommentResp resp = convertToCommentRespWithReplies(comment, user.getId(), replies, mentionIds);

            // 推送WebSocket消息
            try {
                webSocketService.sendCommentCreated(postId, resp);
            } catch (Exception wsEx) {
                log.warn("WebSocket推送失败（不影响主流程）: {}", wsEx.getMessage());
            }

            return ResponseEntity.status(201).body(resp);
        } catch (IllegalArgumentException e) {
            throw new BadRequestException(e.getMessage());
        }
    }

    /**
     * 更新评论
     * PUT /posts/{postId}/comments/{commentId}
     */
    @PutMapping("/{commentId}")
    public ResponseEntity<CommentDtos.CommentResp> updateComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @Valid @RequestBody CommentDtos.UpdateCommentReq req,
            @AuthenticationPrincipal User user) {

        Comment comment = commentService.updateComment(commentId, req.content(), user);
        List<Comment> replies = commentService.getReplies(comment.getId());

        // 从Comment实体中解析mentionIds
        List<Long> mentionIds = parseMentionIds(comment.getMentionIds());
        CommentDtos.CommentResp resp = convertToCommentRespWithReplies(comment, user.getId(), replies, mentionIds);

        // 推送WebSocket消息
        webSocketService.sendCommentUpdated(postId, resp);

        return ResponseEntity.ok(resp);
    }

    /**
     * 删除评论
     * DELETE /posts/{postId}/comments/{commentId}
     */
    @DeleteMapping("/{commentId}")
    public ResponseEntity<CommentDtos.CommentResp> deleteComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @AuthenticationPrincipal User user) {

        commentService.deleteComment(commentId, user);

        // 推送WebSocket消息
        webSocketService.sendCommentDeleted(postId, commentId.toString());

        return ResponseEntity.noContent().build();
    }

    /**
     * 点赞评论
     * POST /posts/{postId}/comments/{commentId}/like
     */
    @PostMapping("/{commentId}/like")
    public ResponseEntity<CommentDtos.LikeResp> likeComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @AuthenticationPrincipal User user) {
        return handleCommentLikeResponse(postId, commentId, user, true);
    }

    /**
     * 取消点赞评论
     * DELETE /posts/{postId}/comments/{commentId}/like
     */
    @DeleteMapping("/{commentId}/like")
    public ResponseEntity<CommentDtos.LikeResp> unlikeComment(
            @PathVariable Long postId,
            @PathVariable Long commentId,
            @AuthenticationPrincipal User user) {
        return handleCommentLikeResponse(postId, commentId, user, false);
    }

    /**
     * 统一的点赞/取消点赞处理
     */
    private ResponseEntity<CommentDtos.LikeResp> handleCommentLikeResponse(
            Long postId, Long commentId, User user, boolean isLike) {
        if (user == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        log.debug("{} comment like: postId={}, commentId={}, userId={}",
                isLike ? "Like" : "Unlike", postId, commentId, user.getId());

        boolean result = isLike ? likeService.likeComment(commentId, user)
                                : likeService.unlikeComment(commentId, user);

        long likesCount = likeService.getCommentLikesCount(commentId);
        boolean isLiked = likeService.isCommentLiked(commentId, user.getId());

        try {
            webSocketService.sendCommentLikeUpdate(postId, commentId.toString(), (int) likesCount, isLiked);
        } catch (Exception wsEx) {
            log.warn("WebSocket推送失败（不影响主流程）: {}", wsEx.getMessage());
        }

        return ResponseEntity.ok(new CommentDtos.LikeResp((int) likesCount, isLiked));
    }

    /**
     * 将Comment实体转换为CommentResp DTO
     */
    private CommentDtos.CommentResp convertToCommentResp(Comment comment, Long userId) {
        List<Comment> replies = commentService.getReplies(comment.getId());
        // 从Comment实体中解析mentionIds
        List<Long> mentionIds = parseMentionIds(comment.getMentionIds());
        return convertToCommentRespWithReplies(comment, userId, replies, mentionIds);
    }

    private List<Long> parseMentionIds(String mentionIdsStr) {
        if (mentionIdsStr == null || mentionIdsStr.trim().isEmpty()) {
            return List.of();
        }
        try {
            return java.util.Arrays.stream(mentionIdsStr.split(","))
                .filter(s -> !s.trim().isEmpty())
                .map(Long::parseLong)
                .collect(Collectors.toList());
        } catch (Exception e) {
            log.warn("解析mentionIds失败: {}", e.getMessage());
            return List.of();
        }
    }

    private CommentDtos.CommentResp convertToCommentRespWithReplies(Comment comment, Long userId, List<Comment> replies, List<Long> mentionIds) {
        User author = comment.getAuthor();
        String authorName = author.getName() != null && !author.getName().isEmpty()
            ? author.getName()
            : (author.getEmail().contains("@")
                ? author.getEmail().substring(0, author.getEmail().indexOf("@"))
                : author.getEmail());
        CommentDtos.AuthorInfo authorInfo = new CommentDtos.AuthorInfo(
            author.getId(),
            author.getEmail(),
            authorName,
            resolveAvatar(author.getAvatar()),
            author.getAffiliation()
        );

        CommentDtos.AuthorInfo replyToInfo = null;
        if (comment.getReplyTo() != null) {
            User replyTo = comment.getReplyTo();
            String replyToName = replyTo.getName() != null && !replyTo.getName().isEmpty()
                ? replyTo.getName()
                : (replyTo.getEmail().contains("@")
                    ? replyTo.getEmail().substring(0, replyTo.getEmail().indexOf("@"))
                    : replyTo.getEmail());
            replyToInfo = new CommentDtos.AuthorInfo(
                replyTo.getId(),
                replyTo.getEmail(),
                replyToName,
                resolveAvatar(replyTo.getAvatar()),
                replyTo.getAffiliation()
            );
        }

        boolean isLiked = userId != null && likeService.isCommentLiked(comment.getId(), userId);

        List<CommentDtos.CommentResp> replyList = replies.stream()
            .map(reply -> {
                User replyAuthor = reply.getAuthor();
                String replyAuthorName = replyAuthor.getName() != null && !replyAuthor.getName().isEmpty()
                    ? replyAuthor.getName()
                    : (replyAuthor.getEmail().contains("@")
                        ? replyAuthor.getEmail().substring(0, replyAuthor.getEmail().indexOf("@"))
                        : replyAuthor.getEmail());
                CommentDtos.AuthorInfo replyAuthorInfo = new CommentDtos.AuthorInfo(
                    replyAuthor.getId(),
                    replyAuthor.getEmail(),
                    replyAuthorName,
                    resolveAvatar(replyAuthor.getAvatar()),
                    replyAuthor.getAffiliation()
                );

                CommentDtos.AuthorInfo replyReplyToInfo = null;
                if (reply.getReplyTo() != null) {
                    User replyReplyTo = reply.getReplyTo();
                    String replyReplyToName = replyReplyTo.getName() != null && !replyReplyTo.getName().isEmpty()
                        ? replyReplyTo.getName()
                        : (replyReplyTo.getEmail().contains("@")
                            ? replyReplyTo.getEmail().substring(0, replyReplyTo.getEmail().indexOf("@"))
                            : replyReplyTo.getEmail());
                    replyReplyToInfo = new CommentDtos.AuthorInfo(
                        replyReplyTo.getId(),
                        replyReplyTo.getEmail(),
                        replyReplyToName,
                        resolveAvatar(replyReplyTo.getAvatar()),
                        replyReplyTo.getAffiliation()
                    );
                }

                boolean replyIsLiked = userId != null && likeService.isCommentLiked(reply.getId(), userId);

                // 解析楼中楼回复的mentions
                List<CommentDtos.AuthorInfo> replyMentionInfos = new ArrayList<>();
                List<Long> replyMentionIds = parseMentionIds(reply.getMentionIds());
                log.debug("楼中楼回复 @{} 的 mentionIds: {}, 解析结果: {}", reply.getId(), reply.getMentionIds(), replyMentionIds);
                if (replyMentionIds != null && !replyMentionIds.isEmpty()) {
                    for (Long mentionId : replyMentionIds) {
                        userRepository.findById(mentionId).ifPresent(mentionedUser -> {
                            String mentionedUserName = mentionedUser.getName() != null && !mentionedUser.getName().isEmpty()
                                ? mentionedUser.getName()
                                : (mentionedUser.getEmail().contains("@")
                                    ? mentionedUser.getEmail().substring(0, mentionedUser.getEmail().indexOf("@"))
                                    : mentionedUser.getEmail());
                            replyMentionInfos.add(new CommentDtos.AuthorInfo(
                                mentionedUser.getId(),
                                mentionedUser.getEmail(),
                                mentionedUserName,
                                resolveAvatar(mentionedUser.getAvatar()),
                                mentionedUser.getAffiliation()
                            ));
                        });
                    }
                }

                return new CommentDtos.CommentResp(
                    reply.getId().toString(),
                    replyAuthorInfo,
                    reply.getContent(),
                    reply.getParent() != null ? reply.getParent().getId().toString() : null,
                    replyReplyToInfo,
                    reply.getLikesCount(),
                    replyIsLiked,
                    reply.getCreatedAt().atOffset(ZoneOffset.UTC).toString(),
                    List.of(), // 回复的回复不再嵌套
                    replyMentionInfos // 支持楼中楼@功能
                );
            })
            .collect(Collectors.toList());

        // 构建被@的用户信息列表
        List<CommentDtos.AuthorInfo> mentionInfos = new ArrayList<>();
        if (mentionIds != null && !mentionIds.isEmpty()) {
            for (Long mentionId : mentionIds) {
                userRepository.findById(mentionId).ifPresent(mentionedUser -> {
                    String mentionedUserName = mentionedUser.getName() != null && !mentionedUser.getName().isEmpty()
                        ? mentionedUser.getName()
                        : (mentionedUser.getEmail().contains("@")
                            ? mentionedUser.getEmail().substring(0, mentionedUser.getEmail().indexOf("@"))
                            : mentionedUser.getEmail());
                    mentionInfos.add(new CommentDtos.AuthorInfo(
                        mentionedUser.getId(),
                        mentionedUser.getEmail(),
                        mentionedUserName,
                        resolveAvatar(mentionedUser.getAvatar()),
                        mentionedUser.getAffiliation()
                    ));
                });
            }
        }

        return new CommentDtos.CommentResp(
            comment.getId().toString(),
            authorInfo,
            comment.getContent(),
            comment.getParent() != null ? comment.getParent().getId().toString() : null,
            replyToInfo,
            comment.getLikesCount(),
            isLiked,
            comment.getCreatedAt().atOffset(ZoneOffset.UTC).toString(),
            replyList,
            mentionInfos
        );
    }

    private String resolveAvatar(String avatar) {
        if (avatar == null || avatar.trim().isEmpty()) {
            return "images/DefaultAvatar.png";
        }
        // 如果数据库中存储的是带 assets/ 前缀的路径，去掉前缀
        if (avatar.equals("assets/images/DefaultAvatar.png")) {
            return "images/DefaultAvatar.png";
        }
        return avatar;
    }
}
