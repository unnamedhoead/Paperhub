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
import org.springframework.web.bind.annotation.RestController;

import java.util.Optional;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
    }

    record MessageResponse(String message) {
    }
}
