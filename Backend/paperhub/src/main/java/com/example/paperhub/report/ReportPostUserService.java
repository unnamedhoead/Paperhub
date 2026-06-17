package com.example.paperhub.report;

import com.example.paperhub.admin.ReportStatus;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostStatus;
import com.example.paperhub.report.dto.PostDetailResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Arrays;
import java.util.List;

/**
 * User-facing report & post workflow service.
 * Handles: report a post, view post detail (with visibility), save draft, submit for audit.
 */
@Service
public class ReportPostUserService {

    private final ReportPostRepository reportPostRepository;
    private final PostRepository postRepository;
    private final UserRepository userRepository;
    private final PostVisibilityResolver visibilityResolver;

    public ReportPostUserService(ReportPostRepository reportPostRepository,
                                  PostRepository postRepository,
                                  UserRepository userRepository,
                                  PostVisibilityResolver visibilityResolver) {
        this.reportPostRepository = reportPostRepository;
        this.postRepository = postRepository;
        this.userRepository = userRepository;
        this.visibilityResolver = visibilityResolver;
    }

    /**
     * User reports a post.
     */
    @Transactional
    public ReportPost reportPost(Long postId, String description, User reporter) {
        if (reporter == null) {
            throw new BadRequestException("用户未登录");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        if (reportPostRepository.existsByReporterAndPost(reporter, post)) {
            throw new BadRequestException("您已经举报过该帖子");
        }

        if (post.getAuthor().getId().equals(reporter.getId())) {
            throw new BadRequestException("不能举报自己的帖子");
        }

        ReportPost report = new ReportPost();
        report.setReporter(reporter);
        report.setPost(post);
        report.setDescription(description);
        report.setStatus(ReportStatus.PENDING);
        report.setReportTime(Instant.now());

        return reportPostRepository.save(report);
    }

    /**
     * Get post detail with visibility based on PostStatus and user identity.
     * Uses strategy pattern for visibility logic.
     */
    public PostDetailResponse getPostDetail(Long postId, User currentUser) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        PostVisibilityPolicy.PostVisibilityResult result = visibilityResolver.resolve(post, currentUser);

        return new PostDetailResponse(
                post.getId(),
                post.getTitle(),
                post.getContent(),
                post.getMedia(),
                post.getTags(),
                post.getAuthor().getId(),
                post.getAuthor().getName(),
                post.getStatus().name(),
                post.getHiddenReason(),
                result.visible(),
                result.canEdit(),
                result.message(),
                post.getCreatedAt(),
                post.getUpdatedAt()
        );
    }

    /**
     * Author saves a draft after editing a removed/draft post.
     */
    @Transactional
    public Post saveDraft(Long postId, String title, String content,
                         List<String> media, List<String> tags, User author) {
        if (author == null) {
            throw new BadRequestException("用户未登录");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        if (!post.getAuthor().getId().equals(author.getId())) {
            throw new BadRequestException("只有作者本人可以修改帖子");
        }

        if (post.getStatus() != PostStatus.REMOVED && post.getStatus() != PostStatus.DRAFT) {
            throw new BadRequestException("只有被下架的帖子才能修改");
        }

        post.setTitle(title);
        post.setContent(content);
        if (media != null) {
            post.setMedia(media);
        }
        if (tags != null) {
            post.setTags(tags);
        }
        post.setStatus(PostStatus.DRAFT);
        post.setUpdatedAt(Instant.now());

        return postRepository.save(post);
    }

    /**
     * Author submits a draft for audit.
     */
    @Transactional
    public Post submitForAudit(Long postId, User author) {
        if (author == null) {
            throw new BadRequestException("用户未登录");
        }

        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在"));

        if (!post.getAuthor().getId().equals(author.getId())) {
            throw new BadRequestException("只有作者本人可以提交审核");
        }

        if (post.getStatus() != PostStatus.DRAFT) {
            throw new BadRequestException("只有草稿状态的帖子才能提交审核");
        }

        post.setStatus(PostStatus.AUDIT);
        post.setUpdatedAt(Instant.now());

        return postRepository.save(post);
    }

    /**
     * Query author's removed/draft/audit posts.
     */
    public Page<Post> getAuthorRemovedPosts(Long authorId, Pageable pageable) {
        return postRepository.findByAuthorIdAndStatusInOrderByCreatedAtDesc(
                authorId,
                Arrays.asList(PostStatus.REMOVED, PostStatus.DRAFT, PostStatus.AUDIT),
                pageable
        );
    }
}
