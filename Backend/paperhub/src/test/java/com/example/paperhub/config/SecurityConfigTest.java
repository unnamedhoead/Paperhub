package com.example.paperhub.config;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.jwt.JwtService;
import com.example.paperhub.jwt.TokenBlacklistService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Optional;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// Slice test for the security filter chain: public whitelist, JWT filter, and role-based gating.
@WebMvcTest(controllers = SecurityConfigTest.TestController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, SecurityConfigTest.TestController.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class SecurityConfigTest {
    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private JwtService jwtService;

    @MockBean
    private UserRepository userRepository;

    @MockBean
    private TokenBlacklistService tokenBlacklistService;

    @Test
    void authEndpointIsPublic() throws Exception {
        mockMvc.perform(get("/auth/ping"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("auth-ok"));
    }

    @Test
    void adminEndpointWithoutTokenIsUnauthorized() throws Exception {
        mockMvc.perform(get("/admin/ping").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void adminEndpointRejectsNonAdminRole() throws Exception {
        mockUserToken("user-token", UserRole.USER);

        mockMvc.perform(get("/admin/ping").header("Authorization", "Bearer user-token"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value(403));
    }

    @Test
    void adminEndpointAllowsAdminRole() throws Exception {
        mockUserToken("admin-token", UserRole.ADMIN);

        mockMvc.perform(get("/admin/ping").header("Authorization", "Bearer admin-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("admin-ok"));
    }

    // ── 白名单完整性矩阵（FM8 修复：证明收紧未打挂公开浏览、且匿名写被拦） ──

    @Test
    void publicPostGetIsAnonymous() throws Exception {
        // 匿名可浏览帖子流（公开内容 GET）
        mockMvc.perform(get("/posts/feed-ping"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("posts-ok"));
    }

    @Test
    void publicHotSearchGetIsAnonymous() throws Exception {
        mockMvc.perform(get("/hot-searches/ping"))
                .andExpect(status().isOk());
    }

    @Test
    void publicUserProfileGetIsAnonymous() throws Exception {
        // GET /users/{id} 公开查看他人资料
        mockMvc.perform(get("/users/42"))
                .andExpect(status().isOk());
    }

    @Test
    void writeWithoutTokenIsUnauthorized() throws Exception {
        // 匿名写操作（发帖/点赞…）被安全层拦截，不再依赖 controller 自查
        mockMvc.perform(post("/posts/feed-ping").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void privateHistoryWithoutTokenIsUnauthorized() throws Exception {
        // 私有数据域（浏览历史）匿名 GET 也被拦截
        mockMvc.perform(get("/browse-history/ping").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void privateUsersMeWithoutTokenIsUnauthorized() throws Exception {
        // /users/me 私有，匿名被拦（而 /users/{id} 公开）
        mockMvc.perform(get("/users/me").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void writeWithTokenIsAllowed() throws Exception {
        mockUserToken("user-token", UserRole.USER);
        mockMvc.perform(post("/posts/feed-ping").header("Authorization", "Bearer user-token"))
                .andExpect(status().isOk());
    }

    private void mockUserToken(String token, UserRole role) {
        User user = new User();
        user.setEmail(role.name().toLowerCase() + "@example.com");
        user.setVerified(true);
        user.setRole(role);

        when(jwtService.validateToken(token)).thenReturn(true);
        when(tokenBlacklistService.isBlacklisted(token)).thenReturn(false);
        when(jwtService.extractEmail(token)).thenReturn(user.getEmail());
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
    }

    @RestController
    static class TestController {
        @GetMapping("/auth/ping")
        MessageResponse authPing() {
            return new MessageResponse("auth-ok");
        }

        @GetMapping("/admin/ping")
        MessageResponse adminPing() {
            return new MessageResponse("admin-ok");
        }

        @GetMapping("/posts/feed-ping")
        MessageResponse postsGet() {
            return new MessageResponse("posts-ok");
        }

        @PostMapping("/posts/feed-ping")
        MessageResponse postsPost() {
            return new MessageResponse("posts-write-ok");
        }

        @GetMapping("/hot-searches/ping")
        MessageResponse hotGet() {
            return new MessageResponse("hot-ok");
        }

        @GetMapping("/users/{id}")
        MessageResponse userPublicGet() {
            return new MessageResponse("user-public-ok");
        }

        @GetMapping("/users/me")
        MessageResponse userMeGet() {
            return new MessageResponse("user-me-ok");
        }

        @GetMapping("/browse-history/ping")
        MessageResponse historyGet() {
            return new MessageResponse("history-ok");
        }
    }

    record MessageResponse(String message) {
    }
}
