package com.example.paperhub.auth;

import com.example.paperhub.common.exception.NotFoundException;
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
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(controllers = AuthController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AuthService authService;
    @MockBean
    private JwtService jwtService;
    @MockBean
    private UserRepository userRepository;
    @MockBean
    private TokenBlacklistService tokenBlacklistService;

    // ── register ──

    @Test
    void registerShouldReturn201WithMessage() throws Exception {
        mockMvc.perform(post("/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"a@b.com\",\"password\":\"pass123\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.message").value("注册成功，已发送验证邮件"))
                .andExpect(jsonPath("$.token").doesNotExist());
    }

    @Test
    void registerShouldReturn400WhenEmailMissing() throws Exception {
        mockMvc.perform(post("/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"password\":\"pass123\"}"))
                .andExpect(status().isBadRequest());
    }

    // ── send-verification ──

    @Test
    void sendVerificationShouldReturn200() throws Exception {
        mockMvc.perform(post("/auth/send-verification")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"a@b.com\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("已重新发送验证邮件"));
    }

    // ── verify ──

    @Test
    void verifyShouldReturn200() throws Exception {
        mockMvc.perform(post("/auth/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"a@b.com\",\"code\":\"123456\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("验证成功，注册完成"));
    }

    // ── login ──

    @Test
    void loginShouldReturnTokenFields() throws Exception {
        User mockUser = new User();
        mockUser.setId(1L);
        mockUser.setEmail("a@b.com");
        mockUser.setVerified(true);

        when(authService.validateLogin(eq("a@b.com"), eq("pass123"))).thenReturn(mockUser);
        when(jwtService.generateToken("a@b.com", 1L)).thenReturn("token-xxx");
        when(jwtService.generateRefreshToken("a@b.com", 1L)).thenReturn("refresh-xxx");
        when(jwtService.getExpiresInSeconds()).thenReturn(3600L);
        when(jwtService.getRefreshExpiresInSeconds()).thenReturn(7200L);

        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"a@b.com\",\"password\":\"pass123\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("登录成功"))
                .andExpect(jsonPath("$.token").value("token-xxx"))
                .andExpect(jsonPath("$.refreshToken").value("refresh-xxx"))
                .andExpect(jsonPath("$.expiresIn").value(3600))
                .andExpect(jsonPath("$.refreshExpiresIn").value(7200));
    }

    @Test
    void loginShouldReturn401WhenCredentialsWrong() throws Exception {
        when(authService.validateLogin(eq("a@b.com"), eq("wrong")))
                .thenThrow(new NotFoundException("邮箱未注册，请先注册并完成邮件验证"));

        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"a@b.com\",\"password\":\"wrong\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(404));
    }

    // ── request-reset ──

    @Test
    void requestResetShouldReturn200() throws Exception {
        mockMvc.perform(post("/auth/request-reset")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"a@b.com\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("重置邮件已发送"));
    }

    // ── reset-password ──

    @Test
    void resetPasswordShouldReturn200() throws Exception {
        mockMvc.perform(post("/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"a@b.com\",\"code\":\"123456\",\"newPassword\":\"newpass\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("密码已重置"));
    }

    // ── refresh ──

    @Test
    void refreshShouldReturnNewTokens() throws Exception {
        User mockUser = new User();
        mockUser.setId(1L);
        mockUser.setEmail("a@b.com");
        mockUser.setVerified(true);

        when(jwtService.validateRefreshToken("old-refresh")).thenReturn(true);
        when(jwtService.extractEmail("old-refresh")).thenReturn("a@b.com");
        when(authService.findByEmail("a@b.com")).thenReturn(Optional.of(mockUser));
        when(jwtService.generateToken("a@b.com", 1L)).thenReturn("new-token");
        when(jwtService.generateRefreshToken("a@b.com", 1L)).thenReturn("new-refresh");
        when(jwtService.getExpiresInSeconds()).thenReturn(3600L);
        when(jwtService.getRefreshExpiresInSeconds()).thenReturn(7200L);

        mockMvc.perform(post("/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"old-refresh\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("new-token"))
                .andExpect(jsonPath("$.refreshToken").value("new-refresh"))
                .andExpect(jsonPath("$.expiresIn").value(3600))
                .andExpect(jsonPath("$.refreshExpiresIn").value(7200));
    }

    @Test
    void refreshShouldReturn401WhenTokenInvalid() throws Exception {
        when(jwtService.validateRefreshToken("bad-token")).thenReturn(false);

        mockMvc.perform(post("/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"bad-token\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }
}
