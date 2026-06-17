package com.example.paperhub.like;

import com.example.paperhub.auth.User;
import com.example.paperhub.comment.Comment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CommentLikeRepository extends JpaRepository<CommentLike, Long> {
    Optional<CommentLike> findByCommentAndUser(Comment comment, User user);
    boolean existsByCommentIdAndUserId(Long commentId, Long userId);
    long countByCommentId(Long commentId);
    void deleteByCommentIdIn(List<Long> commentIds);

    @Modifying
    @Query("UPDATE Comment c SET c.likesCount = c.likesCount + :delta WHERE c.id = :commentId")
    void incrementCommentLikesCount(@Param("commentId") Long commentId, @Param("delta") int delta);

    @Modifying
    @Query("UPDATE Comment c SET c.likesCount = :count WHERE c.id = :commentId")
    void setCommentLikesCount(@Param("commentId") Long commentId, @Param("count") int count);
}

