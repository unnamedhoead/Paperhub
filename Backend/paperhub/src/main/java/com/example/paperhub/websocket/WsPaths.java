package com.example.paperhub.websocket;

/**
 * WebSocket path constants shared between config and handlers.
 */
public final class WsPaths {

    private WsPaths() {}

    public static final String POSTS        = "/ws/posts";
    public static final String ADMIN        = "/ws/admin";
    public static final String NOTIFICATIONS = "/ws/notifications";
    public static final String CHAT         = "/ws/chat";

    // Used by SimpleWebSocketConfig
    public static final String POSTS_TPL        = POSTS + "/{postId}";
    public static final String NOTIFICATIONS_TPL = NOTIFICATIONS + "/{userId}";
    public static final String CHAT_TPL         = CHAT + "/{userId}";
}
