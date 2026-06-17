package com.example.paperhub.websocket.message;

import com.example.paperhub.chat.dto.MessageResponse;
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for new chat messages pushed to conversation participants.
 */
public class ChatMessage {
    private final String type;
    private final Long conversationId;
    private final MessageResponse message;

    @JsonCreator
    public ChatMessage(
            @JsonProperty("type") String type,
            @JsonProperty("conversationId") Long conversationId,
            @JsonProperty("message") MessageResponse message) {
        this.type = type;
        this.conversationId = conversationId;
        this.message = message;
    }

    public String getType() { return type; }
    public Long getConversationId() { return conversationId; }
    public MessageResponse getMessage() { return message; }
}
