package com.chat.paperhubchating.service;

import com.chat.paperhubchating.pojo.Conversation;
import com.chat.paperhubchating.pojo.Message;
import com.chat.paperhubchating.repository.ConversationRepository;
import com.chat.paperhubchating.repository.MessageRepository;
import com.chat.paperhubchating.service.impl.IConversationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class ConversationService implements IConversationService {

    @Autowired
    private ConversationRepository conversationRepository;

    @Autowired
    private MessageRepository messageRepository;


    public List<Map<String, Object>> getUserConversations(Long userId) {
        List<Conversation> conversations = conversationRepository.findAllByUserId(userId);
        List<Map<String, Object>> result = new ArrayList<>();


        return result;
    }
}