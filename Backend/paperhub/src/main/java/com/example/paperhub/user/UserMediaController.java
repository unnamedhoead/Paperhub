package com.example.paperhub.user;

import com.example.paperhub.auth.User;
import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.config.ObsConfig;
import com.example.paperhub.user.dto.AvatarUploadResp;
import com.example.paperhub.user.dto.BackgroundUploadResp;
import com.obs.services.ObsClient;
import com.obs.services.exception.ObsException;
import java.io.IOException;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

/**
 * 用户媒体上传 API：头像、个人主页背景图。
 */
@RestController
@RequestMapping("/users")
@CrossOrigin(origins = "*")
public class UserMediaController {

    private final UserService userService;
    private final ObsClient obsClient;
    private final ObsConfig obsConfig;

    public UserMediaController(UserService userService,
                                ObsClient obsClient,
                                ObsConfig obsConfig) {
        this.userService = userService;
        this.obsClient = obsClient;
        this.obsConfig = obsConfig;
    }

    /**
     * 上传头像文件并返回可访问的 URL，同时更新用户资料中的 avatar 字段。
     */
    @PostMapping("/me/avatar")
    public ResponseEntity<AvatarUploadResp> uploadAvatar(
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
        String objectKey = "avatars/" + UUID.randomUUID() + extension;
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + objectKey;

        try {
            obsClient.putObject(obsConfig.getBucketName(), objectKey, file.getInputStream());
            currentUser.setAvatar(url);
            userService.saveUser(currentUser);
            return ResponseEntity.ok(new AvatarUploadResp(url, "头像上传成功"));
        } catch (ObsException e) {
            throw new RuntimeException("头像上传失败: " + e.getErrorMessage());
        } catch (IOException e) {
            throw new RuntimeException("头像上传失败: " + e.getMessage());
        }
    }

    /**
     * 上传个人主页背景图。
     */
    @PostMapping("/me/background")
    public ResponseEntity<BackgroundUploadResp> uploadBackground(
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
        String objectKey = "profile-bg/" + UUID.randomUUID() + extension;
        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + objectKey;
        try {
            obsClient.putObject(obsConfig.getBucketName(), objectKey, file.getInputStream());
            currentUser.setProfileBackground(url);
            userService.saveUser(currentUser);
            return ResponseEntity.ok(new BackgroundUploadResp(url, "背景图上传成功"));
        } catch (ObsException e) {
            throw new RuntimeException("背景图上传失败: " + e.getErrorMessage());
        } catch (IOException e) {
            throw new RuntimeException("背景图上传失败: " + e.getMessage());
        }
    }
}
