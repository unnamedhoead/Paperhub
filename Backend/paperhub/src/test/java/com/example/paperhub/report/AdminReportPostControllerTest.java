package com.example.paperhub.report;

import com.example.paperhub.admin.ReportStatus;
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
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AdminReportPostController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class AdminReportPostControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private ReportPostAdminService reportPostAdminService;
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
    void getAllReportsAsAdminReturnsPaginatedList() throws Exception {
        mockAdmin();
        when(reportPostAdminService.getAllReports(any()))
                .thenReturn(new PageImpl<>(List.of()));

        mockMvc.perform(get("/api/admin/report/posts")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reports").isArray())
                .andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void getAllReportsAsAnonymousReturns401() throws Exception {
        mockMvc.perform(get("/api/admin/report/posts"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void countPendingReportsReturnsCount() throws Exception {
        mockAdmin();
        when(reportPostAdminService.countPendingReports()).thenReturn(5L);

        mockMvc.perform(get("/api/admin/report/count")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(5));
    }

    @Test
    void removePostAsAdminSucceeds() throws Exception {
        mockAdmin();
        Post post = new Post();
        post.setId(42L);
        post.setStatus(PostStatus.DRAFT);

        ReportPost report = new ReportPost();
        report.setId(1L);
        report.setPost(post);
        report.setStatus(ReportStatus.PROCESSED);
        report.setHandleResult("已打回，原因：违规");

        when(reportPostAdminService.removePost(eq(1L), any(), any()))
                .thenReturn(report);

        mockMvc.perform(post("/api/admin/report/1/remove")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"违规\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("帖子已下架"));
    }

    @Test
    void approvePostAsAdminSucceeds() throws Exception {
        mockAdmin();
        Post post = new Post();
        post.setId(42L);
        post.setStatus(PostStatus.NORMAL);
        when(reportPostAdminService.approvePost(eq(42L), any())).thenReturn(post);

        mockMvc.perform(post("/api/admin/post/42/approve")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("审核通过，帖子已恢复正常"));
    }
}
