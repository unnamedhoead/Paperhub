package com.example.paperhub.auth.dto;

public record RefreshTokenResp(
        String token,
        String refreshToken,
        long expiresIn,
        long refreshExpiresIn
) {}
