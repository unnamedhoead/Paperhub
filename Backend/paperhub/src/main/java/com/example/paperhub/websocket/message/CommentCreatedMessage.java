package com.example.paperhub.websocket.message;

import com.example.paperhub.comment.dto.CommentDtos;
import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for new comment notifications.
 */
public class CommentCreatedMessage {
    private final String type;
    private final CommentDtos.CommentResp comment;

    @JsonCreator
    public CommentCreatedMessage(
            @JsonProperty("type") String type,
            @JsonProperty("comment") CommentDtos.CommentResp comment) {
        this.type = type;
        this.comment = comment;
    }

    public String getType() { return type; }
    public CommentDtos.CommentResp getComment() { return comment; }
}
