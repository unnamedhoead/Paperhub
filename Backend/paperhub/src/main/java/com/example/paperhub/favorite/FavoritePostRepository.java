package com.example.paperhub.favorite;

import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface FavoritePostRepository extends JpaRepository<FavoritePost, Long> {
    boolean existsByUserIdAndPostId(Long userId, Long postId);
    void deleteByUserIdAndPostId(Long userId, Long postId);
    Page<FavoritePost> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);
    long countByUserId(Long userId);
    long countByPostId(Long postId);
    long countByPostAuthorId(Long authorId);
    Optional<FavoritePost> findByUserIdAndPostId(Long userId, Long postId);
    void deleteByPostId(Long postId);

    @Modifying
    @Query("UPDATE Post p SET p.favoriteCount = p.favoriteCount + :delta WHERE p.id = :postId")
    void incrementFavoriteCount(@Param("postId") Long postId, @Param("delta") int delta);
}

