package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.post.Post;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface BrowseHistoryRepository extends JpaRepository<BrowseHistory, Long> {

    Optional<BrowseHistory> findByUserAndPost(User user, Post post);

    /**
     * 用户浏览历史，按浏览时间倒序（最新在前）。
     * 配合 {@link Pageable} 可限制返回数量（用于展示）。
     */
    List<BrowseHistory> findByUserOrderByViewedAtDesc(User user, Pageable pageable);

    /**
     * 取用户最近 50 条浏览记录（按浏览时间倒序）。
     * 注意：本方法仍被 {@code post.RecommendationService} 使用，故予以保留；
     * BrowseHistoryService 自身的容量裁剪已改用 {@link #countByUser} +
     * {@link #findIdsByUserOrderByViewedAtDesc} 真正强制上限。
     */
    List<BrowseHistory> findTop50ByUserOrderByViewedAtDesc(User user);

    /** 用户浏览历史的真实总条数（用于容量裁剪判断）。 */
    long countByUser(User user);

    /**
     * 用户全部浏览记录的 id，按浏览时间倒序。
     * 用于容量裁剪：跳过最新的 N 条后，其余即为需要删除的旧记录 id。
     * 只查 id，避免加载整行实体。
     */
    @Query("SELECT h.id FROM BrowseHistory h WHERE h.user = :user ORDER BY h.viewedAt DESC")
    List<Long> findIdsByUserOrderByViewedAtDesc(@Param("user") User user);

    void deleteByUserAndPost(User user, Post post);

    void deleteByPost(Post post);
}


