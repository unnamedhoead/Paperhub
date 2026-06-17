package com.example.paperhub.websocket;

import com.example.paperhub.chat.dto.MessageResponse;
import com.example.paperhub.websocket.message.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Arrays;

/**
 * Chat WebSocket service — builds typed message wrappers and delegates to
 * {@link ChatWebSocketHandler} for delivery.
 */
@Service
public class ChatWebSocketService {

    private static final Logger log = LoggerFactory.getLogger(ChatWebSocketService.class);

    private final ChatWebSocketHandler chatWebSocketHandler;

    public ChatWebSocketService(ChatWebSocketHandler chatWebSocketHandler) {
        this.chatWebSocketHandler = chatWebSocketHandler;
    }

    /** Push a new message to all participants of a conversation. */
    public void sendNewMessage(Long conversationId, MessageResponse message, Long... participantIds) {
        ChatMessage msg = new ChatMessage("new_message", conversationId, message);
        chatWebSocketHandler.sendToUsers(Arrays.asList(participantIds), msg);
    }

    /** Push a message-read acknowledgement. */
    public void sendMessageRead(Long conversationId, Long userId, Long messageId) {
        MessageReadMessage msg = new MessageReadMessage("message_read", conversationId, userId, messageId);
        chatWebSocketHandler.sendToUser(userId, msg);
    }

    /** Push a typing indicator. */
    public void sendTypingStatus(Long conversationId, Long userId, String userName, boolean isTyping) {
        TypingMessage msg = new TypingMessage("typing", conversationId, userId, userName, isTyping);
        chatWebSocketHandler.sendToUser(userId, msg);
    }

    /** Push an online-status change. */
    public void sendOnlineStatus(Long userId, boolean isOnline) {
        OnlineStatusMessage msg = new OnlineStatusMessage("online_status", userId, isOnline);
        chatWebSocketHandler.sendToUser(userId, msg);
    }
}
