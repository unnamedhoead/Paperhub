package com.example.paperhub.admin;

import com.example.paperhub.admin.dto.AdminApplicationReq;
import com.example.paperhub.admin.dto.AdminApplicationResp;
import com.example.paperhub.admin.dto.SimpleUserInfo;
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

@WebMvcTest(controllers = AdminPermissionController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class AdminPermissionControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private AdminService adminService;
    @MockBean private JwtService jwtService;
    @MockBean private UserRepository userRepository;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private static final String TOKEN = "valid-token";

    private void mockUser(UserRole role) {
        User u = new User();
        u.setId(1L);
        u.setEmail("u@test.com");
        u.setVerified(true);
        u.setRole(role);
        when(jwtService.validateToken(TOKEN)).thenReturn(true);
        when(tokenBlacklistService.isBlacklisted(TOKEN)).thenReturn(false);
        when(jwtService.extractEmail(TOKEN)).thenReturn(u.getEmail());
        when(userRepository.findByEmail(u.getEmail())).thenReturn(Optional.of(u));
    }

    @Test
    void grantAdminRequiresSuperAdmin() throws Exception {
        // Admin cannot grant admin
        mockUser(UserRole.ADMIN);
        mockMvc.perform(post("/admin/permissions/5/grant-admin")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isForbidden());
    }

    @Test
    void grantAdminAsSuperAdminSucceeds() throws Exception {
        mockUser(UserRole.SUPER_ADMIN);
        mockMvc.perform(post("/admin/permissions/5/grant-admin")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("已授予管理员权限"));
    }

    @Test
    void revokeAdminRequiresSuperAdmin() throws Exception {
        mockUser(UserRole.ADMIN);
        mockMvc.perform(post("/admin/permissions/5/revoke-admin")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isForbidden());
    }

    @Test
    void listApplicationsRequiresSuperAdmin() throws Exception {
        mockUser(UserRole.ADMIN);
        mockMvc.perform(get("/admin/applications")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isForbidden());
    }

    @Test
    void listApplicationsAsSuperAdminSucceeds() throws Exception {
        mockUser(UserRole.SUPER_ADMIN);
        when(adminService.listApplications(isNull(), any()))
                .thenReturn(new PageImpl<>(List.of()));

        mockMvc.perform(get("/admin/applications")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.applications").isArray())
                .andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void createApplicationAsAdminSucceeds() throws Exception {
        mockUser(UserRole.ADMIN);
        User recommender = new User();
        recommender.setId(1L);
        recommender.setName("Admin");
        recommender.setEmail("admin@t.com");
        recommender.setRole(UserRole.ADMIN);
        recommender.setStatus(com.example.paperhub.auth.UserStatus.NORMAL);

        User candidate = new User();
        candidate.setId(5L);
        candidate.setName("Candidate");
        candidate.setEmail("c@t.com");
        candidate.setRole(UserRole.USER);
        candidate.setStatus(com.example.paperhub.auth.UserStatus.NORMAL);

        AdminApplication app = new AdminApplication();
        app.setId(1L);
        app.setRecommender(recommender);
        app.setCandidate(candidate);
        app.setReason("Good contributor");
        app.setStatus(AdminApplicationStatus.PENDING);
        app.setCreatedAt(Instant.now());

        when(adminService.createAdminApplication(any(AdminApplicationReq.class), any()))
                .thenReturn(app);

        mockMvc.perform(post("/admin/applications")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"candidateUserId\":5,\"reason\":\"Good contributor\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reason").value("Good contributor"));
    }

    @Test
    void approveApplicationRequiresSuperAdmin() throws Exception {
        mockUser(UserRole.ADMIN);
        mockMvc.perform(post("/admin/applications/1/approve")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isForbidden());
    }
}
