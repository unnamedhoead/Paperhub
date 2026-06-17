package com.example.paperhub.websocket.message;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * WebSocket message for post favorite updates.
 */
public class FavoriteUpdateMessage {
    private final String type;
    private final int favoriteCount;
    private final boolean isSaved;

    @JsonCreator
    public FavoriteUpdateMessage(
            @JsonProperty("type") String type,
            @JsonProperty("favoriteCount") int favoriteCount,
            @JsonProperty("isSaved") boolean isSaved) {
        this.type = type;
        this.favoriteCount = favoriteCount;
        this.isSaved = isSaved;
    }

    public String getType() { return type; }
    public int getFavoriteCount() { return favoriteCount; }
    @JsonProperty("isSaved")
    public boolean isSaved() { return isSaved; }
}
