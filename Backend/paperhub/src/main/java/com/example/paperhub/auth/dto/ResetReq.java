package com.example.paperhub.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record ResetReq(
        @Email @NotBlank String email,
        @NotBlank String code,
        @NotBlank String newPassword
) {}
