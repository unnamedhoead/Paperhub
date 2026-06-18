package com.example.paperhub.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record VerifyReq(
        @Email @NotBlank String email,
        @NotBlank String code
) {}
