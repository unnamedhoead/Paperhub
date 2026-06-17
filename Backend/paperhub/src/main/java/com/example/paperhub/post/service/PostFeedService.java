package com.example.paperhub.post.service;

import com.example.paperhub.post.FollowFeedRepository;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.post.PostStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;

/**
 * Feed-related queries: paginated post listing with optional tag filter, and following feed.
 */
@Service
public class PostFeedService {

    private static final Logger log = LoggerFactory.getLogger(PostFeedService.class);

    static final List<String> MAIN_DISCIPLINES = Arrays.asList(
            "理学", "工学", "信息科学（CS）", "生命科学", "医学与健康",
            "经管", "社会科学", "人文与艺术", "教育学", "跨学科",
            "科研方法与工具", "学术生活", "公告区"
    );

    private final PostRepository postRepository;
    private final FollowFeedRepository followFeedRepository;

    public PostFeedService(PostRepository postRepository,
                           FollowFeedRepository followFeedRepository) {
        this.postRepository = postRepository;
        this.followFeedRepository = followFeedRepository;
    }

    /**
     * 获取帖子列表（分页）- 只返回正常状态的帖子
     */
    public Page<Post> getPosts(int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return postRepository.findByStatusOrderByCreatedAtDesc(PostStatus.NORMAL, pageable);
    }

    /**
     * 获取帖子列表（分页），支持按标签过滤
     */
    public Page<Post> getPosts(int page, int pageSize, String tag) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        if (tag != null && !tag.trim().isEmpty()) {
            String trimmedTag = tag.trim();
            if (MAIN_DISCIPLINES.contains(trimmedTag)) {
                return postRepository.findByMainDisciplineOrderByCreatedAtDesc(trimmedTag, pageable);
            } else {
                return postRepository.findByTagOrderByCreatedAtDesc(trimmedTag, pageable);
            }
        } else {
            return postRepository.findAllByOrderByCreatedAtDesc(pageable);
        }
    }

    /**
     * 获取"关注"信息流：只包含当前用户关注的作者发布的帖子。
     */
    public Page<Post> getFollowingFeed(Long followerId, int page, int pageSize) {
        Pageable pageable = PageRequest.of(page - 1, pageSize);
        return followFeedRepository.findFollowingPosts(followerId, pageable);
    }
}
