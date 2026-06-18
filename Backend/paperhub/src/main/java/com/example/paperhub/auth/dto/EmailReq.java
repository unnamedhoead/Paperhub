package com.example.paperhub.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record EmailReq(
        @Email @NotBlank String email
) {}
