package com.example.paperhub.post;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.service.PostCrudService;
import com.example.paperhub.post.service.PostDraftService;
import com.example.paperhub.post.service.PostFeedService;
import com.example.paperhub.post.service.PostSearchService;
import com.example.paperhub.post.service.PostReportDelegate;
import com.example.paperhub.report.ReportPost;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * Backward-compatible facade that delegates to the new split services.
 * External callers (LikeService, CommentService, UserController) continue to use this class.
 * New post/ controllers use the split services directly.
 */
@Service
public class PostService {

    private static final Logger log = LoggerFactory.getLogger(PostService.class);

    private final PostCrudService postCrudService;
    private final PostFeedService postFeedService;
    private final PostSearchService postSearchService;
    private final PostDraftService postDraftService;
    private final PostReportDelegate reportPostService;

    public PostService(PostCrudService postCrudService,
                       PostFeedService postFeedService,
                       PostSearchService postSearchService,
                       PostDraftService postDraftService,
                       PostReportDelegate reportPostService) {
        this.postCrudService = postCrudService;
        this.postFeedService = postFeedService;
        this.postSearchService = postSearchService;
        this.postDraftService = postDraftService;
        this.reportPostService = reportPostService;
    }

    public Optional<Post> findById(Long id) {
        return postCrudService.findById(id);
    }

    public Page<Post> getPosts(int page, int pageSize) {
        return postFeedService.getPosts(page, pageSize);
    }

    public Page<Post> getPostsByAuthor(Long authorId, int page, int pageSize) {
        return postCrudService.getPostsByAuthor(authorId, page, pageSize);
    }

    public Page<Post> getPosts(int page, int pageSize, String tag) {
        return postFeedService.getPosts(page, pageSize, tag);
    }

    public Page<Post> getFollowingFeed(Long followerId, int page, int pageSize) {
        return postFeedService.getFollowingFeed(followerId, page, pageSize);
    }

    public Page<Post> searchPosts(String keyword, String searchType, String sort, int page, int pageSize) {
        return postSearchService.searchPosts(keyword, searchType, sort, page, pageSize);
    }

    @Transactional
    public Post createPost(String title, String content, User author, List<String> media,
                          String mainDiscipline, String doi, String journal, Integer year, List<String> externalLinks,
                          String arxivId, List<String> arxivAuthors, String arxivPublishedDate, List<String> arxivCategories,
                          List<Long> references, String status) {
        return postCrudService.createPost(title, content, author, media, mainDiscipline, doi, journal, year,
                externalLinks, arxivId, arxivAuthors, arxivPublishedDate, arxivCategories, references, status);
    }

    @Transactional
    public Post updatePost(Long postId, User operator, String title, String content, List<String> media,
                          String mainDiscipline, String doi, String journal, Integer year, List<String> externalLinks,
                          String arxivId, List<String> arxivAuthors, String arxivPublishedDate, List<String> arxivCategories,
                          List<Long> references, String status) {
        return postCrudService.updatePost(postId, operator, title, content, media, mainDiscipline, doi, journal, year,
                externalLinks, arxivId, arxivAuthors, arxivPublishedDate, arxivCategories, references, status);
    }

    @Transactional
    public Post save(Post post) {
        return postCrudService.save(post);
    }

    @Transactional
    public void incrementViewsCount(Long postId) {
        postCrudService.incrementViewsCount(postId);
    }

    @Transactional
    public void incrementLikesCount(Long postId) {
        postCrudService.incrementLikesCount(postId);
    }

    @Transactional
    public void decrementLikesCount(Long postId) {
        postCrudService.decrementLikesCount(postId);
    }

    @Transactional
    public void incrementCommentsCount(Long postId) {
        postCrudService.incrementCommentsCount(postId);
    }

    @Transactional
    public void decrementCommentsCount(Long postId) {
        postCrudService.decrementCommentsCount(postId);
    }

    @Transactional
    public void deletePost(Long postId, Long operatorId) {
        postCrudService.deletePost(postId, operatorId);
    }

    @Transactional
    public ReportPost reportPost(Long postId, String description, User reporter) {
        return reportPostService.reportPost(postId, description, reporter);
    }

    @Transactional
    public Post saveDraft(Long postId, Long userId) {
        return postDraftService.saveDraft(postId, userId);
    }

    public Page<Post> getUserDrafts(Long userId, int page, int pageSize) {
        return postDraftService.getUserDrafts(userId, page, pageSize);
    }
}

