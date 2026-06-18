package com.example.paperhub.admin;

import com.example.paperhub.admin.dto.NoticeReq;
import com.example.paperhub.admin.dto.NoticeResp;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.config.GlobalExceptionHandler;
import com.example.paperhub.config.JwtAuthenticationFilter;
import com.example.paperhub.config.SecurityConfig;
import com.example.paperhub.jwt.JwtService;
import com.example.paperhub.jwt.TokenBlacklistService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AdminNoticeController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class AdminNoticeControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private AdminService adminService;
    @MockBean private JwtService jwtService;
    @MockBean private UserRepository userRepository;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private static final String TOKEN = "valid-token";

    private void mockAdmin() {
        User u = new User();
        u.setId(1L);
        u.setEmail("admin@test.com");
        u.setVerified(true);
        u.setRole(UserRole.ADMIN);
        when(jwtService.validateToken(TOKEN)).thenReturn(true);
        when(tokenBlacklistService.isBlacklisted(TOKEN)).thenReturn(false);
        when(jwtService.extractEmail(TOKEN)).thenReturn(u.getEmail());
        when(userRepository.findByEmail(u.getEmail())).thenReturn(Optional.of(u));
    }

    @Test
    void listNoticesReturnsPaginatedResults() throws Exception {
        mockAdmin();
        AdminNotice n = new AdminNotice();
        n.setId(1L);
        n.setTitle("Test Notice");
        n.setContent("Content");
        n.setPublished(true);
        n.setCreatedAt(Instant.now());
        n.setUpdatedAt(Instant.now());
        when(adminService.listNotices(isNull(), any()))
                .thenReturn(new PageImpl<>(List.of(n)));

        mockMvc.perform(get("/admin/notices")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.notices").isArray())
                .andExpect(jsonPath("$.notices[0].title").value("Test Notice"))
                .andExpect(jsonPath("$.total").value(1));
    }

    @Test
    void createNoticeAsAdminReturnsNoticeResp() throws Exception {
        mockAdmin();
        AdminNotice n = new AdminNotice();
        n.setId(1L);
        n.setTitle("New");
        n.setContent("Body");
        n.setPublished(true);
        n.setCreatedAt(Instant.now());
        n.setUpdatedAt(Instant.now());
        when(adminService.createNotice(any(NoticeReq.class))).thenReturn(n);

        mockMvc.perform(post("/admin/notices")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"New\",\"content\":\"Body\",\"published\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("New"));
    }

    @Test
    void deleteNoticeAsAdminReturnsMessage() throws Exception {
        mockAdmin();
        mockMvc.perform(delete("/admin/notices/1")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("删除成功"));
    }

    @Test
    void listNoticesAsAnonymousReturns401() throws Exception {
        mockMvc.perform(get("/admin/notices"))
                .andExpect(status().isUnauthorized());
    }
}
