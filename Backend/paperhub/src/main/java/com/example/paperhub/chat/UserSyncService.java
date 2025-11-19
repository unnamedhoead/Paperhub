package com.example.paperhub.chat;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Map;
import java.util.Optional;

/**
 * 用户同步服务
 * 负责将PaperHub的用户同步到EasyChat系统
 */
@Service
public class UserSyncService {

    private final UserRepository userRepository;
    private final RestTemplate restTemplate;
    private final String easyChatBaseUrl = "http://localhost:8081";

    @Autowired
    public UserSyncService(UserRepository userRepository, RestTemplate restTemplate) {
        this.userRepository = userRepository;
        this.restTemplate = restTemplate;
    }

    /**
     * 同步用户到EasyChat系统
     * 当用户注册或验证成功后调用
     */
    public void syncUserToEasyChat(User user) {
        try {
            // 检查用户是否已经在EasyChat中存在
            if (!isUserExistsInEasyChat(user)) {
                // 创建EasyChat用户
                createEasyChatUser(user);
            }
        } catch (Exception e) {
            // 记录错误但不中断流程
            System.err.println("同步用户到EasyChat失败: " + e.getMessage());
        }
    }

    /**
     * 检查用户是否在EasyChat中存在
     */
    private boolean isUserExistsInEasyChat(User user) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.set("token", "admin_token"); // 使用管理员令牌

            HttpEntity<String> entity = new HttpEntity<>(headers);

            ResponseEntity<Map> response = restTemplate.exchange(
                easyChatBaseUrl + "/account/checkUser?email=" + user.getEmail(),
                HttpMethod.GET,
                entity,
                Map.class
            );

            return response.getStatusCode().is2xxSuccessful();
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * 在EasyChat中创建用户
     */
    private void createEasyChatUser(User user) {
        try {
            // 构建创建用户请求
            Map<String, Object> createUserRequest = Map.of(
                "email", user.getEmail(),
                "nickName", user.getEmail().split("@")[0], // 使用邮箱前缀作为昵称
                "password", generateDefaultPassword(), // 生成默认密码
                "checkCodeKey", "paperhub_sync",
                "checkCode", "0000" // 简化验证码
            );

            HttpHeaders headers = new HttpHeaders();
            headers.set("Content-Type", "application/json");

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(createUserRequest, headers);

            ResponseEntity<Map> response = restTemplate.exchange(
                easyChatBaseUrl + "/account/register",
                HttpMethod.POST,
                entity,
                Map.class
            );

            if (!response.getStatusCode().is2xxSuccessful()) {
                throw new RuntimeException("创建EasyChat用户失败: " + response.getBody());
            }

            System.out.println("成功同步用户到EasyChat: " + user.getEmail());

        } catch (Exception e) {
            throw new RuntimeException("创建EasyChat用户时出错: " + e.getMessage(), e);
        }
    }

    /**
     * 生成默认密码
     */
    private String generateDefaultPassword() {
        // 生成一个随机的默认密码
        // 在实际生产环境中，应该使用更安全的密码生成策略
        return "paperhub_" + System.currentTimeMillis();
    }

    /**
     * 获取EasyChat用户ID
     * 用于在聊天系统中标识用户
     */
    public String getEasyChatUserId(String email) {
        // 这里可以根据业务逻辑生成EasyChat用户ID
        // 例如使用邮箱的hash值或其他唯一标识
        return "ph_" + email.hashCode();
    }
}