package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for post status updates (admin notifications).
 */
public class PostStatusUpdateMessage {
    private final String type;
    private final Long postId;
    private final String status;
    private final String title;

    @JsonCreator
    public PostStatusUpdateMessage(
            @JsonProperty("type") String type,
            @JsonProperty("postId") Long postId,
            @JsonProperty("status") String status,
            @JsonProperty("title") String title) {
        this.type = type;
        this.postId = postId;
        this.status = status;
        this.title = title;
    }

    public String getType() { return type; }
    public Long getPostId() { return postId; }
    public String getStatus() { return status; }
    public String getTitle() { return title; }
}
