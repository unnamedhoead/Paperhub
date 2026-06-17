package com.example.paperhub.admin.dto;

public record SimpleUserInfo(
        Long id,
        String name,
        String email,
        String role,
        String status
) {}
