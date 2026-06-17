package com.example.paperhub.report.dto;

import com.example.paperhub.admin.ReportStatus;
import com.example.paperhub.post.PostStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;

/**
 * Request DTO for reporting a post.
 */
public record ReportPostRequest(
        @NotNull(message = "帖子ID不能为空")
        Long postId,

        @NotBlank(message = "举报描述不能为空")
        String description
) {}
