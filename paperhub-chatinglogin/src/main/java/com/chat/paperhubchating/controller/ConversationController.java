package com.chat.paperhubchating.controller;


import com.chat.paperhubchating.service.impl.IConversationService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/conversation")
public class ConversationController {

    @Autowired
    private IConversationService conversationService;

    // 获取指定用户的会话列表
    @GetMapping("/list/{userId}")
    public List<Map<String, Object>> getUserConversations(@PathVariable Long userId) {
        return conversationService.getUserConversations(userId);
    }


}
