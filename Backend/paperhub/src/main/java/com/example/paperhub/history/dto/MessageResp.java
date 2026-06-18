package com.example.paperhub.history.dto;

/**
 * 通用 {@code {"message": "..."}} 响应，用于 history 模块的写操作返回。
 *
 * <p>JSON 兼容性：前端写操作仅依据 HTTP 状态码判断成功，成功体形态保持 {@code {"message": ...}}。
 */
public record MessageResp(String message) {
    public static MessageResp ok() {
        return new MessageResp("ok");
    }
}
