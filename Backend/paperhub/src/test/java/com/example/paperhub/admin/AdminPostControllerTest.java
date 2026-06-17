package com.example.paperhub.admin;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.config.GlobalExceptionHandler;
import com.example.paperhub.config.JwtAuthenticationFilter;
import com.example.paperhub.config.SecurityConfig;
import com.example.paperhub.jwt.JwtService;
import com.example.paperhub.jwt.TokenBlacklistService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AdminPostController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class AdminPostControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private AdminService adminService;
    @MockBean private JwtService jwtService;
    @MockBean private UserRepository userRepository;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private static final String TOKEN = "valid-token";

    private void mockAdmin() {
        User user = new User();
        user.setId(1L);
        user.setEmail("admin@test.com");
        user.setVerified(true);
        user.setRole(UserRole.ADMIN);
        when(jwtService.validateToken(TOKEN)).thenReturn(true);
        when(tokenBlacklistService.isBlacklisted(TOKEN)).thenReturn(false);
        when(jwtService.extractEmail(TOKEN)).thenReturn(user.getEmail());
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
    }

    @Test
    void hidePostAsAdminReturnsMessage() throws Exception {
        mockAdmin();
        mockMvc.perform(post("/admin/posts/42/hide")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("帖子已下架"));
    }

    @Test
    void hidePostAsAnonymousReturns401() throws Exception {
        mockMvc.perform(post("/admin/posts/42/hide"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void searchPostsAsAdminReturnsPaginatedResults() throws Exception {
        mockAdmin();
        Post p = new Post();
        p.setId(1L);
        p.setTitle("Test Post");
        p.setStatus(PostStatus.NORMAL);
        when(adminService.searchPosts(isNull(), isNull(), any()))
                .thenReturn(new PageImpl<>(List.of(p)));

        mockMvc.perform(get("/admin/posts")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.posts").isArray())
                .andExpect(jsonPath("$.posts[0].title").value("Test Post"))
                .andExpect(jsonPath("$.total").value(1));
    }

    @Test
    void approveAuditPostAsAdminReturnsMessage() throws Exception {
        mockAdmin();
        mockMvc.perform(post("/admin/post/1/approve-audit")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("审核通过"));
    }

    @Test
    void rejectAuditPostAsAdminReturnsMessage() throws Exception {
        mockAdmin();
        mockMvc.perform(post("/admin/post/1/reject-audit")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType("application/json")
                        .content("{\"reason\":\"质量不合格\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("已打回草稿"));
    }
}
