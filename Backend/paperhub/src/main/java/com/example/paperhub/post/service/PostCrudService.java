package com.example.paperhub.post.service;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.comment.CommentRepository;
import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.favorite.FavoritePostRepository;
import com.example.paperhub.history.BrowseHistoryRepository;
import com.example.paperhub.like.CommentLikeRepository;
import com.example.paperhub.like.PostLikeRepository;
import com.example.paperhub.notification.NotificationRepository;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostStatus;
import com.example.paperhub.report.ReportPostRepository;
import com.example.paperhub.websocket.WebSocketService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Core CRUD operations for posts: create, read, update, delete, and counter management.
 */
@Service
public class PostCrudService {

    private static final Logger log = LoggerFactory.getLogger(PostCrudService.class);

    private final PostRepository postRepository;
    private final PostLikeRepository postLikeRepository;
    private final FavoritePostRepository favoritePostRepository;
    private final CommentRepository commentRepository;
    private final CommentLikeRepository commentLikeRepository;
    private final ReportPostRepository reportPostRepository;
    private final BrowseHistoryRepository browseHistoryRepository;
    private final NotificationRepository notificationRepository;
    private final WebSocketService webSocketService;

    public PostCrudService(PostRepository postRepository,
                           PostLikeRepository postLikeRepository,
                           FavoritePostRepository favoritePostRepository,
                           CommentRepository commentRepository,
                           CommentLikeRepository commentLikeRepository,
                           ReportPostRepository reportPostRepository,
                           BrowseHistoryRepository browseHistoryRepository,
                           NotificationRepository notificationRepository,
                           WebSocketService webSocketService) {
        this.postRepository = postRepository;
        this.postLikeRepository = postLikeRepository;
        this.favoritePostRepository = favoritePostRepository;
        this.commentRepository = commentRepository;
        this.commentLikeRepository = commentLikeRepository;
        this.reportPostRepository = reportPostRepository;
        this.browseHistoryRepository = browseHistoryRepository;
        this.notificationRepository = notificationRepository;
        this.webSocketService = webSocketService;
    }

    /**
     * 从正文内容中提取二级标签（#标签）
     */
    public List<String> extractSubTagsFromContent(String content) {
        List<String> subTags = new ArrayList<>();
        if (content == null || content.isEmpty()) {
            return subTags;
        }
        Pattern pattern = Pattern.compile("#([^\\s#]+)");
        Matcher matcher = pattern.matcher(content);
        while (matcher.find()) {
            String tag = matcher.group(1);
            if (tag != null && !tag.trim().isEmpty()) {
                subTags.add(tag.trim());
            }
        }
        return subTags;
    }

    public Optional<Post> findById(Long id) {
        return postRepository.findById(id);
    }

    public Page<Post> getPostsByAuthor(Long authorId, int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return postRepository.findByAuthorIdAndStatusOrderByCreatedAtDesc(authorId, PostStatus.NORMAL, pageable);
    }

    @Transactional
    public Post createPost(String title, String content, User author, List<String> media,
                          String mainDiscipline, String doi, String journal, Integer year, List<String> externalLinks,
                          String arxivId, List<String> arxivAuthors, String arxivPublishedDate, List<String> arxivCategories,
                          List<Long> references, String status) {
        ensureUserCanInteract(author);
        Post post = new Post();
        post.setTitle(title);
        post.setContent(content != null ? content : "");
        post.setAuthor(author);
        post.setMedia(media != null ? media : List.of());
        post.setMainDiscipline(mainDiscipline);

        List<String> subTags = extractSubTagsFromContent(content);
        post.setTags(subTags);

        post.setDoi(doi);
        post.setJournal(journal);
        post.setYear(year);
        post.setExternalLinks(externalLinks != null ? externalLinks : List.of());
        post.setArxivId(arxivId);
        post.setArxivAuthors(arxivAuthors != null ? arxivAuthors : List.of());
        post.setArxivPublishedDate(arxivPublishedDate);
        post.setArxivCategories(arxivCategories != null ? arxivCategories : List.of());
        post.setReferences(references != null ? references : List.of());

        if ("DRAFT".equalsIgnoreCase(status)) {
            post.setStatus(PostStatus.DRAFT);
        } else {
            post.setStatus(PostStatus.NORMAL);
        }

        post.setLikesCount(0);
        post.setCommentsCount(0);
        post.setViewsCount(0);
        post.setCreatedAt(Instant.now());
        post.setUpdatedAt(Instant.now());

        return postRepository.save(post);
    }

    @Transactional
    public Post updatePost(Long postId, User operator, String title, String content, List<String> media,
                          String mainDiscipline, String doi, String journal, Integer year, List<String> externalLinks,
                          String arxivId, List<String> arxivAuthors, String arxivPublishedDate, List<String> arxivCategories,
                          List<Long> references, String status) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        if (operator == null || !post.getAuthor().getId().equals(operator.getId())) {
            throw new ForbiddenException("无权编辑他人的笔记");
        }

        post.setTitle(title);
        post.setContent(content != null ? content : "");
        post.setMedia(media != null ? media : List.of());
        post.setMainDiscipline(mainDiscipline);

        List<String> subTags = extractSubTagsFromContent(content);
        post.setTags(subTags);

        post.setDoi(doi);
        post.setJournal(journal);
        post.setYear(year);
        post.setExternalLinks(externalLinks != null ? externalLinks : List.of());
        post.setArxivId(arxivId);
        post.setArxivAuthors(arxivAuthors != null ? arxivAuthors : List.of());
        post.setArxivPublishedDate(arxivPublishedDate);
        post.setArxivCategories(arxivCategories != null ? arxivCategories : List.of());
        post.setReferences(references != null ? references : List.of());

        if (status != null && !status.isBlank()) {
            PostStatus targetStatus;
            try {
                targetStatus = PostStatus.valueOf(status.toUpperCase());
            } catch (IllegalArgumentException ex) {
                throw new IllegalArgumentException("不支持的帖子状态: " + status);
            }
            switch (targetStatus) {
                case DRAFT -> {
                    post.setStatus(PostStatus.DRAFT);
                    post.setVisibleToAuthor(true);
                }
                case NORMAL -> {
                    post.setStatus(PostStatus.NORMAL);
                    post.setHiddenReason(null);
                    post.setUpdatedByAdmin(null);
                    post.setVisibleToAuthor(true);
                }
                case AUDIT -> {
                    post.setStatus(PostStatus.AUDIT);
                    post.setVisibleToAuthor(true);
                    try {
                        webSocketService.sendPostStatusUpdate(postId, "AUDIT", post.getTitle());
                    } catch (Exception e) {
                        log.warn("发送WebSocket通知失败: {}", e.getMessage());
                    }
                }
                default -> throw new IllegalArgumentException("不允许更新到该状态: " + targetStatus.name());
            }
        }

        post.setUpdatedAt(Instant.now());
        return postRepository.save(post);
    }

    @Transactional
    public Post save(Post post) {
        return postRepository.save(post);
    }

    @Transactional
    public void incrementViewsCount(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        post.setViewsCount(post.getViewsCount() + 1);
        postRepository.save(post);
    }

    @Transactional
    public void incrementLikesCount(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        post.setLikesCount(post.getLikesCount() + 1);
        postRepository.save(post);
    }

    @Transactional
    public void decrementLikesCount(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        if (post.getLikesCount() > 0) {
            post.setLikesCount(post.getLikesCount() - 1);
            postRepository.save(post);
        }
    }

    @Transactional
    public void incrementCommentsCount(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        post.setCommentsCount(post.getCommentsCount() + 1);
        postRepository.save(post);
    }

    @Transactional
    public void decrementCommentsCount(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));
        if (post.getCommentsCount() > 0) {
            post.setCommentsCount(post.getCommentsCount() - 1);
            postRepository.save(post);
        }
    }

    @Transactional
    public void deletePost(Long postId, Long operatorId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        if (!post.getAuthor().getId().equals(operatorId)) {
            throw new ForbiddenException("无权删除他人的笔记");
        }

        var commentIds = commentRepository.findIdsByPostId(postId);
        if (!commentIds.isEmpty()) {
            commentLikeRepository.deleteByCommentIdIn(commentIds);
            commentRepository.deleteAllById(commentIds);
        }

        postLikeRepository.deleteByPostId(postId);
        favoritePostRepository.deleteByPostId(postId);
        browseHistoryRepository.deleteByPost(post);
        notificationRepository.deleteByPostId(postId);
        reportPostRepository.deleteByPost(post);
        postRepository.delete(post);
    }

    void ensureUserCanInteract(User user) {
        if (user == null) {
            throw new IllegalArgumentException("未认证用户无法执行此操作");
        }
        if (user.getStatus() == UserStatus.BANNED) {
            throw new IllegalArgumentException("账号已被封禁，无法执行此操作");
        }
        if (user.getStatus() == UserStatus.MUTE) {
            Instant muteUntil = user.getMuteUntil();
            if (muteUntil == null || Instant.now().isBefore(muteUntil)) {
                throw new IllegalArgumentException("账号被禁言中，暂时无法发帖");
            }
        }
    }
}
