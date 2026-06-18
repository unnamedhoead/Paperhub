package com.example.paperhub.report.dto;

import jakarta.validation.constraints.NotBlank;
import java.util.List;

/**
 * Author request to save a draft of a removed post.
 */
public record SaveDraftRequest(
        @NotBlank(message = "标题不能为空")
        String title,

        @NotBlank(message = "内容不能为空")
        String content,

        List<String> media,
        List<String> tags
) {}
