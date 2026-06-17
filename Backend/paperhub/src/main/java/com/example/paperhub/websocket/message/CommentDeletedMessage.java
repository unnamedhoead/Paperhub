package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for comment deletion notifications.
 */
public class CommentDeletedMessage {
    private final String type;
    private final String commentId;

    @JsonCreator
    public CommentDeletedMessage(
            @JsonProperty("type") String type,
            @JsonProperty("commentId") String commentId) {
        this.type = type;
        this.commentId = commentId;
    }

    public String getType() { return type; }
    public String getCommentId() { return commentId; }
}
