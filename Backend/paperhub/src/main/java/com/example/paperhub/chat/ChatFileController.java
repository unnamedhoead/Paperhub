package com.example.paperhub.chat;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.config.ObsConfig;
import com.obs.services.ObsClient;
import com.obs.services.exception.ObsException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/upload")
public class ChatFileController {

    private static final Logger log = LoggerFactory.getLogger(ChatFileController.class);

    private final ObsClient obsClient;
    private final ObsConfig obsConfig;

    public ChatFileController(ObsClient obsClient, ObsConfig obsConfig) {
        this.obsClient = obsClient;
        this.obsConfig = obsConfig;
    }

    /**
     * Upload a chat file (image, doc, etc.) to OBS.
     */
    @PostMapping("/chat-file")
    public ResponseEntity<Map<String, Object>> uploadChatFile(
            @AuthenticationPrincipal User currentUser,
            @RequestParam("file") MultipartFile file) {

        if (currentUser == null) {
            throw new UnauthorizedException("未认证，请先登录");
        }
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("文件不能为空");
        }

        String originalName = file.getOriginalFilename();
        String extension = StringUtils.hasText(originalName) && originalName.contains(".")
                ? originalName.substring(originalName.lastIndexOf('.'))
                : "";

        if (file.getSize() > 50 * 1024 * 1024) {
            throw new BadRequestException("文件大小不能超过50MB");
        }
        if (!isAllowedFileType(extension)) {
            throw new BadRequestException("不支持的文件类型");
        }

        String objectKey = "chat-files/" + UUID.randomUUID() + extension;
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + objectKey;

        try {
            obsClient.putObject(obsConfig.getBucketName(), objectKey, file.getInputStream());
        } catch (ObsException e) {
            log.error("OBS upload failed: {}", e.getErrorMessage(), e);
            throw new RuntimeException("文件上传失败: " + e.getErrorMessage(), e);
        } catch (IOException e) {
            log.error("File read failed: {}", e.getMessage(), e);
            throw new RuntimeException("文件上传失败: " + e.getMessage(), e);
        }

        return ResponseEntity.ok(Map.of(
                "url", url,
                "fileName", originalName,
                "fileSize", file.getSize(),
                "message", "文件上传成功"));
    }

    private boolean isAllowedFileType(String extension) {
        String lowerExt = extension.toLowerCase();
        return lowerExt.equals(".jpg") || lowerExt.equals(".jpeg") || lowerExt.equals(".png") ||
               lowerExt.equals(".gif") || lowerExt.equals(".mp3") || lowerExt.equals(".wav") ||
               lowerExt.equals(".mp4") || lowerExt.equals(".pdf") || lowerExt.equals(".doc") ||
               lowerExt.equals(".docx") || lowerExt.equals(".txt") || lowerExt.equals(".zip") ||
               lowerExt.equals(".rar") || lowerExt.equals(".ppt") || lowerExt.equals(".pptx") ||
               lowerExt.equals(".xls") || lowerExt.equals(".xlsx") || lowerExt.equals(".csv") ||
               lowerExt.equals(".7z") || lowerExt.equals(".exe") || lowerExt.equals(".m4a") ||
               lowerExt.equals(".ogg") || lowerExt.equals(".aac") || lowerExt.equals(".webm");
    }
}
