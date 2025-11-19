package com.example.paperhub.chat;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.jwt.JwtService;
import jakarta.validation.Valid;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 聊天代理控制器
 * 负责将前端请求转发到EasyChat后端，并处理用户认证映射
 */
@RestController
@RequestMapping("/api/chat")
public class ChatProxyController {

    private final RestTemplate restTemplate;
    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final String easyChatBaseUrl = "http://localhost:8081"; // EasyChat服务地址

    @Autowired
    public ChatProxyController(RestTemplate restTemplate, UserRepository userRepository, JwtService jwtService) {
        this.restTemplate = restTemplate;
        this.userRepository = userRepository;
        this.jwtService = jwtService;
    }

    /**
     * 发送消息
     */
    @PostMapping("/sendMessage")
    public ResponseEntity<?> sendMessage(
            @RequestHeader("Authorization") String authHeader,
            @Valid @RequestBody SendMessageRequest request) {

        try {
            // 验证PaperHub用户
            String email = extractEmailFromToken(authHeader);
            Optional<User> userOpt = userRepository.findByEmail(email);
            if (userOpt.isEmpty()) {
                return ResponseEntity.status(401).body(Map.of("message", "用户不存在"));
            }

            User user = userOpt.get();
            if (!user.isVerified()) {
                return ResponseEntity.status(403).body(Map.of("message", "用户未验证"));
            }

            // 构建转发请求
            HttpHeaders headers = new HttpHeaders();
            headers.set("token", createEasyChatToken(user));

            Map<String, Object> easyChatRequest = Map.of(
                "contactId", request.getContactId(),
                "messageContent", request.getMessageContent(),
                "messageType", request.getMessageType(),
                "fileSize", request.getFileSize(),
                "fileName", request.getFileName(),
                "fileType", request.getFileType()
            );

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(easyChatRequest, headers);

            ResponseEntity<Map> response = restTemplate.exchange(
                easyChatBaseUrl + "/chat/sendMessage",
                HttpMethod.POST,
                entity,
                Map.class
            );

            return ResponseEntity.ok(response.getBody());

        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("message", "发送消息失败: " + e.getMessage()));
        }
    }

    /**
     * 获取会话列表
     */
    @GetMapping("/conversations")
    public ResponseEntity<?> getConversations(@RequestHeader("Authorization") String authHeader) {
        try {
            String email = extractEmailFromToken(authHeader);
            Optional<User> userOpt = userRepository.findByEmail(email);
            if (userOpt.isEmpty()) {
                return ResponseEntity.status(401).body(Map.of("message", "用户不存在"));
            }

            User user = userOpt.get();
            if (!user.isVerified()) {
                return ResponseEntity.status(403).body(Map.of("message", "用户未验证"));
            }

            // 转发到EasyChat获取联系人列表（用户和群组）
            HttpHeaders headers = new HttpHeaders();
            headers.set("token", createEasyChatToken(user));

            HttpEntity<String> entity = new HttpEntity<>(headers);

            // 获取用户联系人
            ResponseEntity<Map> userResponse = restTemplate.exchange(
                easyChatBaseUrl + "/contact/loadContact?contactType=USER",
                HttpMethod.GET,
                entity,
                Map.class
            );

            // 获取群组联系人
            ResponseEntity<Map> groupResponse = restTemplate.exchange(
                easyChatBaseUrl + "/contact/loadContact?contactType=GROUP",
                HttpMethod.GET,
                entity,
                Map.class
            );

            // 合并结果
            List<Map<String, Object>> conversations = new ArrayList<>();

            if (userResponse.getStatusCode().is2xxSuccessful() && userResponse.getBody() != null) {
                Map<String, Object> userBody = userResponse.getBody();
                if (userBody.containsKey("data")) {
                    Object userData = userBody.get("data");
                    if (userData instanceof List) {
                        conversations.addAll((List<Map<String, Object>>) userData);
                    }
                }
            }

            if (groupResponse.getStatusCode().is2xxSuccessful() && groupResponse.getBody() != null) {
                Map<String, Object> groupBody = groupResponse.getBody();
                if (groupBody.containsKey("data")) {
                    Object groupData = groupBody.get("data");
                    if (groupData instanceof List) {
                        conversations.addAll((List<Map<String, Object>>) groupData);
                    }
                }
            }

            return ResponseEntity.ok(Map.of("conversations", conversations));

        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("message", "获取会话列表失败: " + e.getMessage()));
        }
    }

    /**
     * 获取消息历史
     * 注意：EasyChat没有直接的获取消息历史端点，这里返回模拟数据
     */
    @GetMapping("/messages/{contactId}")
    public ResponseEntity<?> getMessages(
            @RequestHeader("Authorization") String authHeader,
            @PathVariable String contactId) {
        try {
            String email = extractEmailFromToken(authHeader);
            Optional<User> userOpt = userRepository.findByEmail(email);
            if (userOpt.isEmpty()) {
                return ResponseEntity.status(401).body(Map.of("message", "用户不存在"));
            }

            User user = userOpt.get();
            if (!user.isVerified()) {
                return ResponseEntity.status(403).body(Map.of("message", "用户未验证"));
            }

            // EasyChat没有直接的获取消息历史端点
            // 这里返回模拟消息数据
            List<Map<String, Object>> messages = new ArrayList<>();

            // 添加一些模拟消息
            messages.add(Map.of(
                "id", "msg1",
                "conversationId", contactId,
                "senderId", "other",
                "senderName", "张同学",
                "senderAvatar", "https://via.placeholder.com/50",
                "content", "你好！最近在忙什么？",
                "createdAt", System.currentTimeMillis() - 7200000, // 2小时前
                "isMe", false
            ));

            messages.add(Map.of(
                "id", "msg2",
                "conversationId", contactId,
                "senderId", "me",
                "senderName", "我",
                "senderAvatar", "https://via.placeholder.com/50",
                "content", "在写论文，有点头疼",
                "createdAt", System.currentTimeMillis() - 6600000, // 1小时50分钟前
                "isMe", true
            ));

            messages.add(Map.of(
                "id", "msg3",
                "conversationId", contactId,
                "senderId", "other",
                "senderName", "张同学",
                "senderAvatar", "https://via.placeholder.com/50",
                "content", "论文写得怎么样了？",
                "createdAt", System.currentTimeMillis() - 300000, // 5分钟前
                "isMe", false
            ));

            return ResponseEntity.ok(Map.of("messages", messages));

        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("message", "获取消息失败: " + e.getMessage()));
        }
    }

    /**
     * 从JWT令牌中提取邮箱
     */
    private String extractEmailFromToken(String authHeader) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            return jwtService.extractEmail(token);
        }
        throw new IllegalArgumentException("无效的认证头");
    }

    /**
     * 创建EasyChat认证令牌
     * 这里简化处理，使用一个固定的管理员令牌
     * 在实际生产环境中，应该实现完整的用户同步和令牌管理
     */
    private String createEasyChatToken(User user) {
        // 使用固定的管理员令牌绕过EasyChat认证
        // 注意：这仅用于演示，生产环境需要实现完整的用户同步
        return "admin_token";
    }

    /**
     * 发送消息请求体
     */
    public static class SendMessageRequest {
        private String contactId;
        private String messageContent;
        private Integer messageType = 0; // 0: 文本消息
        private Long fileSize;
        private String fileName;
        private Integer fileType;

        // Getters and Setters
        public String getContactId() { return contactId; }
        public void setContactId(String contactId) { this.contactId = contactId; }

        public String getMessageContent() { return messageContent; }
        public void setMessageContent(String messageContent) { this.messageContent = messageContent; }

        public Integer getMessageType() { return messageType; }
        public void setMessageType(Integer messageType) { this.messageType = messageType; }

        public Long getFileSize() { return fileSize; }
        public void setFileSize(Long fileSize) { this.fileSize = fileSize; }

        public String getFileName() { return fileName; }
        public void setFileName(String fileName) { this.fileName = fileName; }

        public Integer getFileType() { return fileType; }
        public void setFileType(Integer fileType) { this.fileType = fileType; }
    }
}