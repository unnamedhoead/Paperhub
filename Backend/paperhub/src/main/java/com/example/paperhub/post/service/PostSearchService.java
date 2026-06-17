package com.example.paperhub.post.service;

import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

/**
 * Search service for posts: keyword search and tag search with hot/new sorting.
 */
@Service
public class PostSearchService {

    private static final Logger log = LoggerFactory.getLogger(PostSearchService.class);

    private final PostRepository postRepository;

    public PostSearchService(PostRepository postRepository) {
        this.postRepository = postRepository;
    }

    /**
     * 搜索帖子
     * @param keyword 搜索关键词
     * @param searchType 搜索类型：keyword（关键词）、tag（标签）
     * @param sort 排序方式：hot（热度）或new（最新）
     * @param page 页码（从1开始）
     * @param pageSize 每页大小
     * @return 帖子分页结果
     */
    public Page<Post> searchPosts(String keyword, String searchType, String sort, int page, int pageSize) {
        if (keyword == null || keyword.trim().isEmpty()) {
            throw new IllegalArgumentException("搜索关键词不能为空");
        }
        if (!"keyword".equals(searchType) && !"tag".equals(searchType)) {
            throw new IllegalArgumentException("搜索类型必须为 'keyword' 或 'tag'");
        }
        if (!"hot".equals(sort) && !"new".equals(sort)) {
            throw new IllegalArgumentException("排序方式必须为 'hot' 或 'new'");
        }

        Pageable pageable = PageRequest.of(page - 1, pageSize);
        String trimmedKeyword = keyword.trim();

        if ("tag".equals(searchType)) {
            if ("new".equals(sort)) {
                return postRepository.findByTagOrderByCreatedAtDesc(trimmedKeyword, pageable);
            } else {
                return postRepository.findByTagOrderByHot(trimmedKeyword, pageable);
            }
        } else {
            if ("new".equals(sort)) {
                return postRepository.searchByKeywordOrderByNew(trimmedKeyword, pageable);
            } else {
                return postRepository.searchByKeywordOrderByHot(trimmedKeyword, pageable);
            }
        }
    }
}
