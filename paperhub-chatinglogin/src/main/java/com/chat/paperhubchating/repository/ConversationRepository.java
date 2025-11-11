package com.chat.paperhubchating.repository;

import com.chat.paperhubchating.pojo.Conversation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, Long> {

    @Query("SELECT c FROM Conversation c WHERE c.user1Id = :userId OR c.user2Id = :userId ORDER BY c.createdAt DESC")
    List<Conversation> findAllByUserId(Long userId);


}
