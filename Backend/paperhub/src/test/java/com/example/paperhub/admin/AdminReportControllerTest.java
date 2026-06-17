package com.example.paperhub.admin;

import com.example.paperhub.admin.dto.*;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AdminReportController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class AdminReportControllerTest {

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
    void listReportsReturnsPaginatedResults() throws Exception {
        mockAdmin();
        User reporter = new User();
        reporter.setId(10L);
        reporter.setName("Reporter");
        reporter.setEmail("r@t.com");
        reporter.setRole(UserRole.USER);
        reporter.setStatus(com.example.paperhub.auth.UserStatus.NORMAL);

        AdminReport report = new AdminReport();
        report.setId(1L);
        report.setReporter(reporter);
        report.setTargetType(ReportTargetType.POST);
        report.setReason("测试举报");
        report.setStatus(ReportStatus.PENDING);
        report.setCreatedAt(Instant.now());
        report.setUpdatedAt(Instant.now());

        when(adminService.listReports(isNull(), isNull(), isNull(), any()))
                .thenReturn(new PageImpl<>(List.of(report)));

        mockMvc.perform(get("/admin/reports")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reports").isArray())
                .andExpect(jsonPath("$.reports[0].reason").value("测试举报"))
                .andExpect(jsonPath("$.total").value(1));
    }

    @Test
    void listReportsAsAnonymousReturns401() throws Exception {
        mockMvc.perform(get("/admin/reports"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void handleReportAsAdminReturnsReportResp() throws Exception {
        mockAdmin();
        User reporter = new User();
        reporter.setId(10L);
        reporter.setName("R");
        reporter.setEmail("r@t.com");
        reporter.setRole(UserRole.USER);
        reporter.setStatus(com.example.paperhub.auth.UserStatus.NORMAL);

        AdminReport report = new AdminReport();
        report.setId(1L);
        report.setReporter(reporter);
        report.setTargetType(ReportTargetType.POST);
        report.setReason("违规");
        report.setStatus(ReportStatus.RESOLVED);
        report.setResolution("DELETE_POST: resolved");
        report.setCreatedAt(Instant.now());
        report.setUpdatedAt(Instant.now());

        when(adminService.handleReport(eq(1L), eq(ReportAction.DELETE_POST), any(), any()))
                .thenReturn(report);

        mockMvc.perform(post("/admin/reports/1/handle")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"action\":\"DELETE_POST\",\"resolutionNote\":\"resolved\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESOLVED"));
    }
}
