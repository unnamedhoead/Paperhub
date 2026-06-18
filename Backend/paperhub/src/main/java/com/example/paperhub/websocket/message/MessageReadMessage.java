package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for message read status updates.
 */
public class MessageReadMessage {
    private final String type;
    private final Long conversationId;
    private final Long userId;
    private final Long messageId;

    @JsonCreator
    public MessageReadMessage(
            @JsonProperty("type") String type,
            @JsonProperty("conversationId") Long conversationId,
            @JsonProperty("userId") Long userId,
            @JsonProperty("messageId") Long messageId) {
        this.type = type;
        this.conversationId = conversationId;
        this.userId = userId;
        this.messageId = messageId;
    }

    public String getType() { return type; }
    public Long getConversationId() { return conversationId; }
    public Long getUserId() { return userId; }
    public Long getMessageId() { return messageId; }
}
