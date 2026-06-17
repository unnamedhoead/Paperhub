package com.example.paperhub.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record AdminApplicationReq(
        @NotNull Long candidateUserId,
        @NotBlank String reason
) {}
