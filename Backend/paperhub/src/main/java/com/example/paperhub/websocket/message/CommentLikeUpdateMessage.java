package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for comment like updates.
 */
public class CommentLikeUpdateMessage {
    private final String type;
    private final String commentId;
    private final int likesCount;
    private final boolean isLiked;

    @JsonCreator
    public CommentLikeUpdateMessage(
            @JsonProperty("type") String type,
            @JsonProperty("commentId") String commentId,
            @JsonProperty("likesCount") int likesCount,
            @JsonProperty("isLiked") boolean isLiked) {
        this.type = type;
        this.commentId = commentId;
        this.likesCount = likesCount;
        this.isLiked = isLiked;
    }

    public String getType() { return type; }
    public String getCommentId() { return commentId; }
    public int getLikesCount() { return likesCount; }
    @JsonProperty("isLiked")
    public boolean isLiked() { return isLiked; }
}
