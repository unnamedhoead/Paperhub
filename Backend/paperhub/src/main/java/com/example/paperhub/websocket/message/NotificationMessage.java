package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.Map;

/**
 * WebSocket message for new notifications pushed to users.
 */
public class NotificationMessage {
    private final String type;
    private final String notificationType;
    private final Map<String, Object> data;

    @JsonCreator
    public NotificationMessage(
            @JsonProperty("type") String type,
            @JsonProperty("notificationType") String notificationType,
            @JsonProperty("data") Map<String, Object> data) {
        this.type = type;
        this.notificationType = notificationType;
        this.data = data;
    }

    public String getType() { return type; }
    public String getNotificationType() { return notificationType; }
    public Map<String, Object> getData() { return data; }
}
