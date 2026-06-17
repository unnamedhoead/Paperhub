package com.example.paperhub.post.service;

import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

/**
 * Draft-related operations: save as draft, list user drafts.
 */
@Service
public class PostDraftService {

    private static final Logger log = LoggerFactory.getLogger(PostDraftService.class);

    private final PostRepository postRepository;

    public PostDraftService(PostRepository postRepository) {
        this.postRepository = postRepository;
    }

    /**
     * 保存为草稿（用户主动保存）
     */
    @Transactional
    public Post saveDraft(Long postId, Long userId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        if (!post.getAuthor().getId().equals(userId)) {
            throw new ForbiddenException("只能保存自己的帖子为草稿");
        }

        post.setStatus(PostStatus.DRAFT);
        post.setUpdatedAt(Instant.now());
        return postRepository.save(post);
    }

    /**
     * 获取用户的草稿列表
     */
    public Page<Post> getUserDrafts(Long userId, int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return postRepository.findByAuthorIdAndStatusInOrderByCreatedAtDesc(
                userId,
                List.of(PostStatus.DRAFT, PostStatus.AUDIT),
                pageable
        );
    }
}
