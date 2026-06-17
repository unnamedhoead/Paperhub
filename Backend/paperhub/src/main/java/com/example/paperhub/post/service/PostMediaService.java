package com.example.paperhub.post.service;

import com.example.paperhub.config.ObsConfig;
import com.obs.services.ObsClient;
import com.obs.services.exception.ObsException;
import com.obs.services.model.PutObjectResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * Media upload service: handles image and PDF uploads to Huawei OBS.
 */
@Service
public class PostMediaService {

    private static final Logger log = LoggerFactory.getLogger(PostMediaService.class);

    private final ObsClient obsClient;
    private final ObsConfig obsConfig;

    public PostMediaService(ObsClient obsClient, ObsConfig obsConfig) {
        this.obsClient = obsClient;
        this.obsConfig = obsConfig;
    }

    /**
     * Upload a file to OBS. Supports images and PDFs.
     * @return map with keys: message, url, fileName (and errorCode on OBS failure)
     */
    public Map<String, String> uploadFile(MultipartFile file) throws IOException {
        log.info("Starting file upload: {}", file.getOriginalFilename());

        String fileName = System.currentTimeMillis() + "_" + file.getOriginalFilename();
        String contentType = file.getContentType();

        if (!isValidFileType(contentType)) {
            throw new IllegalArgumentException("不支持的文件类型");
        }

        String url = "https://" + obsConfig.getBucketName() + ".obs.cn-north-4.myhuaweicloud.com/" + fileName;
        Map<String, String> result = new HashMap<>();

        try {
            PutObjectResult putResult = obsClient.putObject(obsConfig.getBucketName(), fileName, file.getInputStream());
            log.info("File uploaded successfully: {}", url);
            result.put("message", "文件上传成功");
            result.put("url", url);
            result.put("fileName", fileName);
            return result;
        } catch (ObsException e) {
            log.error("OBS upload failed: code={}, message={}", e.getErrorCode(), e.getErrorMessage());
            result.put("message", "上传失败：" + e.getErrorMessage());
            result.put("errorCode", e.getErrorCode());
            return result;
        }
    }

    private boolean isValidFileType(String contentType) {
        return contentType != null &&
                (contentType.startsWith("image/") || "application/pdf".equals(contentType));
    }
}
