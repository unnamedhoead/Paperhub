package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
public class BrowseHistoryService {

    /** 每个用户最多保留的浏览历史条数。 */
    private static final int MAX_HISTORY_COUNT = 50;

    private final BrowseHistoryRepository historyRepository;
    private final UserRepository userRepository;
    private final PostRepository postRepository;

    public BrowseHistoryService(BrowseHistoryRepository historyRepository,
                                UserRepository userRepository,
                                PostRepository postRepository) {
        this.historyRepository = historyRepository;
        this.userRepository = userRepository;
        this.postRepository = postRepository;
    }

    /**
     * 记录一次浏览：
     * - 如果已有 (user, post) 记录，更新 viewedAt 和标题
     * - 否则新建一条记录
     * - 保证每个用户最多保留 MAX_HISTORY_COUNT 条最新记录
     */
    @Transactional
    public void recordHistory(Long userId, Long postId, String postTitle) {
        User user = requireUser(userId);
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在: " + postId));

        BrowseHistory history = historyRepository.findByUserAndPost(user, post)
                .orElseGet(() -> {
                    BrowseHistory h = new BrowseHistory();
                    h.setUser(user);
                    h.setPost(post);
                    return h;
                });

        history.setPostTitle(postTitle != null ? postTitle : post.getTitle());
        history.setViewedAt(Instant.now());
        historyRepository.save(history);

        enforceHistoryCap(user);
    }

    /**
     * 容量裁剪：真正按总条数判断并删除超出 MAX_HISTORY_COUNT 的最旧记录。
     *
     * <p>修复点：旧实现先用 {@code findTop50...}（最多取 50 条）再判断
     * {@code size() > 50}，由于查询本身被限制在 50 条，该条件永远不成立，
     * 容量裁剪从未真正触发，旧记录会无限累积。现在改为先用真实 {@code countByUser}
     * 判断，超限时取出该用户全部记录 id（按时间倒序），跳过最新的 N 条，
     * 批量删除其余旧记录，从而真正强制执行上限。
     */
    private void enforceHistoryCap(User user) {
        long total = historyRepository.countByUser(user);
        if (total <= MAX_HISTORY_COUNT) {
            return;
        }
        List<Long> idsNewestFirst = historyRepository.findIdsByUserOrderByViewedAtDesc(user);
        if (idsNewestFirst.size() <= MAX_HISTORY_COUNT) {
            return;
        }
        List<Long> idsToDelete = idsNewestFirst.subList(MAX_HISTORY_COUNT, idsNewestFirst.size());
        historyRepository.deleteAllByIdInBatch(idsToDelete);
    }

    @Transactional(readOnly = true)
    public List<BrowseHistory> getHistory(Long userId, int limit) {
        User user = requireUser(userId);
        int effectiveLimit = (limit <= 0 || limit > MAX_HISTORY_COUNT) ? MAX_HISTORY_COUNT : limit;
        Pageable pageable = PageRequest.of(0, effectiveLimit);
        return historyRepository.findByUserOrderByViewedAtDesc(user, pageable);
    }

    @Transactional
    public void deleteOne(Long userId, Long postId) {
        User user = requireUser(userId);
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在: " + postId));
        historyRepository.deleteByUserAndPost(user, post);
    }

    @Transactional
    public void clearAll(Long userId) {
        User user = requireUser(userId);
        List<BrowseHistory> all = historyRepository
                .findByUserOrderByViewedAtDesc(user, Pageable.unpaged());
        historyRepository.deleteAll(all);
    }

    /**
     * 当帖子被删除时调用，清理所有与该帖子相关的浏览记录。
     */
    @Transactional
    public void deleteByPost(Long postId) {
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new NotFoundException("帖子不存在: " + postId));
        historyRepository.deleteByPost(post);
    }

    private User requireUser(Long userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new NotFoundException("用户不存在: " + userId));
    }
}
