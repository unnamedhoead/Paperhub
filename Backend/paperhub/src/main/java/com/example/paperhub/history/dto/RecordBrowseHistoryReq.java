package com.example.paperhub.history.dto;

import com.example.paperhub.common.exception.BadRequestException;
import jakarta.validation.constraints.NotBlank;

/**
 * POST /browse-history 请求体。
 *
 * <p>JSON 兼容性：前端 {@code ApiService.addBrowseHistory} 发送
 * {@code {"postId": "123", "title": "..."}}，其中 postId 为字符串。
 *
 * <p>为保持旧 controller 的错误语义（缺失或非数字的 postId 均返回 400），
 * 这里将 postId 接收为 {@code String}：
 * <ul>
 *   <li>缺失/空白 → {@code @NotBlank} 校验失败 → GlobalExceptionHandler 返回 400；</li>
 *   <li>非数字（如 "abc"）→ {@link #postIdAsLong()} 抛 {@link BadRequestException} → 400。</li>
 * </ul>
 * 若直接用 {@code Long}，非数字字符串会在反序列化阶段抛
 * {@code HttpMessageNotReadableException}，当前未被专门处理会落到 500，属行为回归。
 */
public record RecordBrowseHistoryReq(
        @NotBlank(message = "postId 不能为空") String postId,
        String title
) {
    /** 将 postId 解析为 Long；非数字时抛 400（保持旧行为）。 */
    public Long postIdAsLong() {
        try {
            return Long.parseLong(postId.trim());
        } catch (NumberFormatException e) {
            throw new BadRequestException("postId 必须为数字");
        }
    }
}
