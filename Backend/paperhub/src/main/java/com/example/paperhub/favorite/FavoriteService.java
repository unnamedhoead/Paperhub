package com.example.paperhub.favorite;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserStatus;
import com.example.paperhub.notification.NotificationService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import com.example.paperhub.websocket.WebSocketService;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 收藏帖子相关业务。
 */
@Service
public class FavoriteService {

    private static final Logger log = LoggerFactory.getLogger(FavoriteService.class);

    private final FavoritePostRepository favoriteRepository;
    private final PostRepository postRepository;
    private final NotificationService notificationService;
    private final WebSocketService webSocketService;

    public FavoriteService(
            FavoritePostRepository favoriteRepository,
            PostRepository postRepository,
            NotificationService notificationService,
            WebSocketService webSocketService) {
        this.favoriteRepository = favoriteRepository;
        this.postRepository = postRepository;
        this.notificationService = notificationService;
        this.webSocketService = webSocketService;
    }

    @Transactional
    public void toggleFavorite(Long postId, User user, boolean favorite) {
        ensureUserCanInteract(user);
        Post post = postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("帖子不存在"));

        if (favorite) {
            if (favoriteRepository.existsByUserIdAndPostId(user.getId(), postId)) {
                return;
            }
            FavoritePost fp = new FavoritePost();
            fp.setUser(user);
            fp.setPost(post);
            favoriteRepository.save(fp);
            favoriteRepository.incrementFavoriteCount(postId, 1);
        } else {
            if (!favoriteRepository.existsByUserIdAndPostId(user.getId(), postId)) {
                return;
            }
            favoriteRepository.deleteByUserIdAndPostId(user.getId(), postId);
            favoriteRepository.incrementFavoriteCount(postId, -1);
        }

        // push WebSocket
        webSocketService.sendPostFavoriteUpdate(post.getId(),
                (int) favoriteRepository.countByPostId(postId), favorite);

        // create notification only for favorite (not unfavorite)
        if (favorite) {
            try {
                notificationService.createPostFavoriteNotification(user, postId);
            } catch (Exception e) {
                log.error("创建收藏通知失败", e);
            }
        }
    }

    @Transactional
    public void favoritePost(Long postId, User user) {
        toggleFavorite(postId, user, true);
    }

    @Transactional
    public void unfavoritePost(Long postId, User user) {
        toggleFavorite(postId, user, false);
    }

    public boolean isFavorite(Long postId, Long userId) {
        if (userId == null) return false;
        return favoriteRepository.existsByUserIdAndPostId(userId, postId);
    }

    public long countFavorites(Long userId) {
        return favoriteRepository.countByUserId(userId);
    }

    public long countFavoritesByPostId(Long postId) {
        return favoriteRepository.countByPostId(postId);
    }

    public Page<Post> getFavoritePosts(Long userId, Pageable pageable) {
        Page<FavoritePost> favorites = favoriteRepository.findByUserIdOrderByCreatedAtDesc(userId, pageable);
        List<Post> posts = favorites.stream()
                .map(FavoritePost::getPost)
                .toList();
        return new PageImpl<>(posts, pageable, favorites.getTotalElements());
    }

    private void ensureUserCanInteract(User user) {
        if (user == null) {
            throw new IllegalArgumentException("未认证用户无法执行此操作");
        }
        if (user.getStatus() == UserStatus.BANNED) {
            throw new IllegalArgumentException("账号已被封禁，无法执行此操作");
        }
        if (user.getStatus() == UserStatus.MUTE) {
            java.time.Instant muteUntil = user.getMuteUntil();
            if (muteUntil == null || java.time.Instant.now().isBefore(muteUntil)) {
                throw new IllegalArgumentException("账号被禁言中，暂时无法收藏");
            }
        }
    }
}
