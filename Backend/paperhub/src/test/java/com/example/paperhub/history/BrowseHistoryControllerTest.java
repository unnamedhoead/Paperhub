package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.config.GlobalExceptionHandler;
import com.example.paperhub.config.JwtAuthenticationFilter;
import com.example.paperhub.config.SecurityConfig;
import com.example.paperhub.jwt.JwtService;
import com.example.paperhub.jwt.TokenBlacklistService;
import com.example.paperhub.post.Post;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Slice test for {@link BrowseHistoryController}: validation -> 400, unauthenticated -> 401,
 * happy-path JSON shape (flat fields, NOT wrapped in an ApiResponse "data" envelope).
 * Security wiring mirrors SecurityConfigTest (no spring-security-test on the classpath).
 */
@WebMvcTest(controllers = BrowseHistoryController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class BrowseHistoryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private BrowseHistoryService browseHistoryService;

    @MockBean
    private JwtService jwtService;
    @MockBean
    private UserRepository userRepository;
    @MockBean
    private TokenBlacklistService tokenBlacklistService;

    private static final String TOKEN = "valid-token";

    private void mockAuthenticatedUser(long userId) {
        User user = new User();
        user.setId(userId);
        user.setEmail("u" + userId + "@example.com");
        user.setVerified(true);
        user.setRole(UserRole.USER);
        when(jwtService.validateToken(TOKEN)).thenReturn(true);
        when(tokenBlacklistService.isBlacklisted(TOKEN)).thenReturn(false);
        when(jwtService.extractEmail(TOKEN)).thenReturn(user.getEmail());
        when(userRepository.findByEmail(user.getEmail())).thenReturn(Optional.of(user));
    }

    @Test
    void listReturnsFlatItemsShapeForAuthenticatedUser() throws Exception {
        mockAuthenticatedUser(7L);

        Post post = new Post();
        post.setId(42L);
        BrowseHistory h = new BrowseHistory();
        h.setPost(post);
        h.setPostTitle("Deep Learning");
        h.setViewedAt(Instant.parse("2025-01-01T12:00:00Z"));
        when(browseHistoryService.getHistory(eq(7L), anyInt())).thenReturn(List.of(h));

        mockMvc.perform(get("/browse-history").param("limit", "50")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                // flat top-level fields (frontend reads body['items'] directly, not body['data'])
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.items[0].postId").value(42))
                .andExpect(jsonPath("$.items[0].title").value("Deep Learning"))
                .andExpect(jsonPath("$.items[0].viewedAt").value("2025-01-01T12:00:00Z"))
                .andExpect(jsonPath("$.count").value(1))
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.data").doesNotExist());
    }

    @Test
    void listWithoutTokenIsUnauthorizedWithApiResponseEnvelope() throws Exception {
        // permitAll() lets the request through; the controller null-check is the auth gate.
        mockMvc.perform(get("/browse-history").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void recordWithMissingPostIdFailsValidationWith400() throws Exception {
        mockAuthenticatedUser(7L);

        mockMvc.perform(post("/browse-history")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"no postId here\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void recordWithNonNumericPostIdReturns400NotServerError() throws Exception {
        mockAuthenticatedUser(7L);

        // Behavior-preserving: a non-numeric postId must yield 400 (old Long.parseLong path),
        // not a 500 from an unhandled JSON deserialization error.
        mockMvc.perform(post("/browse-history")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"postId\":\"abc\",\"title\":\"x\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void recordHappyPathCoercesStringPostIdAndReturnsMessage() throws Exception {
        mockAuthenticatedUser(7L);

        // frontend sends postId as a JSON string; Jackson coerces "42" -> Long 42
        mockMvc.perform(post("/browse-history")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"postId\":\"42\",\"title\":\"Deep Learning\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("ok"));

        verify(browseHistoryService).recordHistory(eq(7L), eq(42L), eq("Deep Learning"));
    }

    @Test
    void deleteOneReturnsNoContent() throws Exception {
        mockAuthenticatedUser(7L);

        mockMvc.perform(delete("/browse-history/42")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isNoContent());

        verify(browseHistoryService).deleteOne(7L, 42L);
    }

    @Test
    void clearAllReturnsNoContent() throws Exception {
        mockAuthenticatedUser(7L);

        mockMvc.perform(delete("/browse-history")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isNoContent());

        verify(browseHistoryService).clearAll(7L);
    }
}
