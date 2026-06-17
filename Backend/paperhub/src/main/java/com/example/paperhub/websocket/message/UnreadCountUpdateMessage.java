package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.Map;

/**
 * WebSocket message for unread count updates.
 */
public class UnreadCountUpdateMessage {
    private final String type;
    private final Map<String, Integer> unreadCounts;

    @JsonCreator
    public UnreadCountUpdateMessage(
            @JsonProperty("type") String type,
            @JsonProperty("unreadCounts") Map<String, Integer> unreadCounts) {
        this.type = type;
        this.unreadCounts = unreadCounts;
    }

    public String getType() { return type; }
    public Map<String, Integer> getUnreadCounts() { return unreadCounts; }
}
