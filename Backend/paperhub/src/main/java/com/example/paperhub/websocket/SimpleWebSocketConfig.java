package com.example.paperhub.websocket;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

/**
 * Native (non-STOMP) WebSocket configuration.
 * Path constants are defined in {@link WsPaths}.
 */
@Configuration
@EnableWebSocket
public class SimpleWebSocketConfig implements WebSocketConfigurer {

    private final SimpleWebSocketHandler webSocketHandler;
    private final ChatWebSocketHandler chatWebSocketHandler;

    public SimpleWebSocketConfig(SimpleWebSocketHandler webSocketHandler,
                                 ChatWebSocketHandler chatWebSocketHandler) {
        this.webSocketHandler = webSocketHandler;
        this.chatWebSocketHandler = chatWebSocketHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(webSocketHandler, WsPaths.POSTS_TPL)
                .setAllowedOrigins("*");

        registry.addHandler(webSocketHandler, WsPaths.ADMIN)
                .setAllowedOrigins("*");

        registry.addHandler(webSocketHandler, WsPaths.NOTIFICATIONS_TPL)
                .setAllowedOrigins("*");

        registry.addHandler(chatWebSocketHandler, WsPaths.CHAT_TPL)
                .setAllowedOrigins("*");
    }
}
