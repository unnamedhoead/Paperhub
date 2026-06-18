package com.example.paperhub.user.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

/**
 * 更新个人资料请求体。
 */
public record UpdateProfileReq(
        @NotBlank(message = "昵称不能为空")
        String name,
        String bio,
        List<String> researchDirections,
        String backgroundImage
) {}
