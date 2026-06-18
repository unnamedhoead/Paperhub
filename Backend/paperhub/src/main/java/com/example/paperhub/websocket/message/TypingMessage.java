package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for typing indicator status.
 */
public class TypingMessage {
    private final String type;
    private final Long conversationId;
    private final Long userId;
    private final String userName;
    private final boolean isTyping;

    @JsonCreator
    public TypingMessage(
            @JsonProperty("type") String type,
            @JsonProperty("conversationId") Long conversationId,
            @JsonProperty("userId") Long userId,
            @JsonProperty("userName") String userName,
            @JsonProperty("isTyping") boolean isTyping) {
        this.type = type;
        this.conversationId = conversationId;
        this.userId = userId;
        this.userName = userName;
        this.isTyping = isTyping;
    }

    public String getType() { return type; }
    public Long getConversationId() { return conversationId; }
    public Long getUserId() { return userId; }
    public String getUserName() { return userName; }
    @JsonProperty("isTyping")
    public boolean isTyping() { return isTyping; }
}
