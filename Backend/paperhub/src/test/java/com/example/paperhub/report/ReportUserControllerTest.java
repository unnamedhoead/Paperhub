package com.example.paperhub.report;

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
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = ReportUserController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class ReportUserControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private ReportUserService reportUserService;
    @MockBean private JwtService jwtService;
    @MockBean private UserRepository userRepository;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private static final String TOKEN = "valid-token";

    private void mockUser() {
        User u = new User();
        u.setId(5L);
        u.setEmail("user@test.com");
        u.setVerified(true);
        u.setRole(UserRole.USER);
        when(jwtService.validateToken(TOKEN)).thenReturn(true);
        when(tokenBlacklistService.isBlacklisted(TOKEN)).thenReturn(false);
        when(jwtService.extractEmail(TOKEN)).thenReturn(u.getEmail());
        when(userRepository.findByEmail(u.getEmail())).thenReturn(Optional.of(u));
    }

    @Test
    void reportUserAsAuthenticatedUserSucceeds() throws Exception {
        mockUser();
        doNothing().when(reportUserService).reportUser(eq(10L), eq("违规行为"), any());

        mockMvc.perform(post("/api/report/user/10")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"违规行为\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("举报成功"));
    }

    @Test
    void reportUserWithoutTokenReturns401() throws Exception {
        mockMvc.perform(post("/api/report/user/10")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"违规行为\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void reportUserWithEmptyReasonReturns400() throws Exception {
        mockUser();
        mockMvc.perform(post("/api/report/user/10")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"\"}"))
                .andExpect(status().isBadRequest());
    }
}
