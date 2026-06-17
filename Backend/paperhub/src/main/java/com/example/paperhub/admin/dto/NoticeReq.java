package com.example.paperhub.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record NoticeReq(
        @NotBlank String title,
        String content,
        String attachments,
        @NotNull Boolean published
) {}
