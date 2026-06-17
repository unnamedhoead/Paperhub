package com.example.paperhub.post.api;

import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.post.service.PostMediaService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

/**
 * Media endpoints: image and PDF upload to OBS.
 */
@RestController
@RequestMapping("/posts")
@CrossOrigin(origins = "*")
public class PostMediaController {

    private static final Logger log = LoggerFactory.getLogger(PostMediaController.class);

    private final PostMediaService postMediaService;

    public PostMediaController(PostMediaService postMediaService) {
        this.postMediaService = postMediaService;
    }

    /**
     * Upload image or PDF file
     * POST /posts/upload
     */
    @PostMapping("/upload")
    public ResponseEntity<Map<String, String>> uploadFile(@RequestParam("file") MultipartFile file) {
        log.info("Upload request: {}", file.getOriginalFilename());

        try {
            Map<String, String> result = postMediaService.uploadFile(file);
            if (result.containsKey("errorCode")) {
                // OBS error — return 500 with the error map
                return ResponseEntity.status(500).body(result);
            }
            return ResponseEntity.ok(result);
        } catch (IOException e) {
            log.error("Upload IO error: {}", e.getMessage());
            throw new BadRequestException("文件上传失败: " + e.getMessage());
        } catch (IllegalArgumentException e) {
            throw new BadRequestException(e.getMessage());
        }
    }
}
