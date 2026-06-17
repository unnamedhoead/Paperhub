package com.example.paperhub.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record RefreshTokenReq(
        @NotBlank String refreshToken
) {}
