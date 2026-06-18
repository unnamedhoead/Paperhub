package com.example.paperhub.admin;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.auth.UserStatus;
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

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AdminUserController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class AdminUserControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private AdminService adminService;
    @MockBean private JwtService jwtService;
    @MockBean private UserRepository userRepository;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private static final String TOKEN = "valid-token";

    private void mockUser(long userId, UserRole role) {
        User user = new User();
        user.setId(userId);
        user.setEmail("u" + userId + "@test.com");
        user.setVerified(true);
        user.setRole(role);
        when(jwtService.validateToken(TOKEN)).thenReturn(true);
        when(tokenBlacklistService.isBlacklisted(TOKEN)).thenReturn(false);
        when(jwtService.extractEmail(TOKEN)).thenReturn(user.getEmail());
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
    }

    @Test
    void searchUsersAsAdminReturnsPaginatedResults() throws Exception {
        mockUser(1L, UserRole.ADMIN);
        User u = new User();
        u.setId(10L);
        u.setEmail("test@test.com");
        u.setName("TestUser");
        u.setRole(UserRole.USER);
        u.setStatus(UserStatus.NORMAL);
        when(adminService.searchUsers(isNull(), isNull(), any()))
                .thenReturn(new PageImpl<>(List.of(u)));

        mockMvc.perform(get("/admin/users")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.users").isArray())
                .andExpect(jsonPath("$.users[0].id").value(10))
                .andExpect(jsonPath("$.users[0].name").value("TestUser"))
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.pageSize").value(20));
    }

    @Test
    void searchUsersAsAnonymousReturns401() throws Exception {
        mockMvc.perform(get("/admin/users"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void searchUsersAsNormalUserReturns403() throws Exception {
        mockUser(2L, UserRole.USER);
        mockMvc.perform(get("/admin/users")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isForbidden());
    }

    @Test
    void auditListAsAdminReturnsUsers() throws Exception {
        mockUser(1L, UserRole.ADMIN);
        User u = new User();
        u.setId(20L);
        u.setEmail("audit@test.com");
        u.setName("AuditUser");
        u.setRole(UserRole.USER);
        u.setStatus(UserStatus.AUDIT);
        when(adminService.getAuditUsers()).thenReturn(List.of(u));

        mockMvc.perform(get("/admin/users/audit-list")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.users").isArray())
                .andExpect(jsonPath("$.users[0].status").value("AUDIT"));
    }

    @Test
    void auditListAsAnonymousNowRequiresAuth() throws Exception {
        // Previously the admin check was commented out, now it's enforced by @PreAuthorize
        mockMvc.perform(get("/admin/users/audit-list"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void banUserAsAdminReturnsMessage() throws Exception {
        mockUser(1L, UserRole.ADMIN);
        mockMvc.perform(post("/admin/users/5/ban")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("用户已封禁"));
    }

    @Test
    void muteUserAsAdminReturnsMessage() throws Exception {
        mockUser(1L, UserRole.ADMIN);
        mockMvc.perform(post("/admin/users/5/mute")
                        .header("Authorization", "Bearer " + TOKEN)
                        .param("duration", "7")
                        .param("unit", "DAYS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("用户已禁言"));
    }

    @Test
    void superAdminCanAccessUserEndpoints() throws Exception {
        mockUser(1L, UserRole.SUPER_ADMIN);
        User u = new User();
        u.setId(10L);
        u.setEmail("t@t.com");
        u.setName("T");
        u.setRole(UserRole.USER);
        u.setStatus(UserStatus.NORMAL);
        when(adminService.searchUsers(isNull(), isNull(), any()))
                .thenReturn(new PageImpl<>(List.of(u)));

        mockMvc.perform(get("/admin/users")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk());
    }
}
