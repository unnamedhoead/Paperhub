package com.example.paperhub.auth.dto;

public record LoginResp(
        String message,
        String token,
        String refreshToken,
        long expiresIn,
        long refreshExpiresIn
) {}
