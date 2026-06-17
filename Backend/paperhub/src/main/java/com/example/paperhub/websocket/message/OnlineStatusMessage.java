package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for user online status updates.
 */
public class OnlineStatusMessage {
    private final String type;
    private final Long userId;
    private final boolean isOnline;

    @JsonCreator
    public OnlineStatusMessage(
            @JsonProperty("type") String type,
            @JsonProperty("userId") Long userId,
            @JsonProperty("isOnline") boolean isOnline) {
        this.type = type;
        this.userId = userId;
        this.isOnline = isOnline;
    }

    public String getType() { return type; }
    public Long getUserId() { return userId; }
    @JsonProperty("isOnline")
    public boolean isOnline() { return isOnline; }
}
