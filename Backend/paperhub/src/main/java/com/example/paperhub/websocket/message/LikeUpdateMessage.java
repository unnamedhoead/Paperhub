package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for post like updates.
 */
public class LikeUpdateMessage {
    private final String type;
    private final int likesCount;
    private final boolean isLiked;
    private final String commentId;
    private final Integer commentLikesCount;

    @JsonCreator
    public LikeUpdateMessage(
            @JsonProperty("type") String type,
            @JsonProperty("likesCount") int likesCount,
            @JsonProperty("isLiked") boolean isLiked,
            @JsonProperty("commentId") String commentId,
            @JsonProperty("commentLikesCount") Integer commentLikesCount) {
        this.type = type;
        this.likesCount = likesCount;
        this.isLiked = isLiked;
        this.commentId = commentId;
        this.commentLikesCount = commentLikesCount;
    }

    public String getType() { return type; }
    public int getLikesCount() { return likesCount; }
    @JsonProperty("isLiked")
    public boolean isLiked() { return isLiked; }
    public String getCommentId() { return commentId; }
    public Integer getCommentLikesCount() { return commentLikesCount; }
}
