package com.chat.paperhubchating.repository;


import com.chat.paperhubchating.pojo.Message;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface MessageRepository extends JpaRepository<Message, Long> {

    Optional<Message> findTopByConversationIdOrderBySentAtDesc(Long conversationId);
}
