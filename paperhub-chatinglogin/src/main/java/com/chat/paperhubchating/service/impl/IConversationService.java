package com.chat.paperhubchating.service.impl;

import java.util.List;
import java.util.Map;

public interface IConversationService {
    /**
     * 获取用户的所有会话列表
     * @param userId
     * @return
     */
    List<Map<String, Object>> getUserConversations(Long userId);

}
