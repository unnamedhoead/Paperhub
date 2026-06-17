package com.example.paperhub.history;

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

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Slice test for {@link SearchHistoryController}: validation -> 400, happy path, flat JSON shape,
 * and that a missing record (404) flows through the unified ApiResponse error envelope.
 */
@WebMvcTest(controllers = SearchHistoryController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class SearchHistoryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private SearchHistoryService searchHistoryService;

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
    void listReturnsFlatItemsAndTotal() throws Exception {
        mockAuthenticatedUser(7L);

        SearchHistory h = new SearchHistory();
        h.setId(5L);
        h.setKeyword("transformer");
        h.setSearchType("keyword");
        h.setSearchCount(3);
        h.setCreatedAt(Instant.parse("2025-01-01T10:00:00Z"));
        h.setUpdatedAt(Instant.parse("2025-01-02T10:00:00Z"));
        when(searchHistoryService.getHistory(eq(7L), any())).thenReturn(List.of(h));
        when(searchHistoryService.getHistoryCount(7L)).thenReturn(11L);

        mockMvc.perform(get("/search-history").param("limit", "20")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(5))
                .andExpect(jsonPath("$.items[0].keyword").value("transformer"))
                .andExpect(jsonPath("$.items[0].searchType").value("keyword"))
                .andExpect(jsonPath("$.items[0].searchCount").value(3))
                .andExpect(jsonPath("$.items[0].createdAt").value("2025-01-01T10:00:00Z"))
                .andExpect(jsonPath("$.items[0].updatedAt").value("2025-01-02T10:00:00Z"))
                .andExpect(jsonPath("$.count").value(1))
                .andExpect(jsonPath("$.total").value(11))
                .andExpect(jsonPath("$.data").doesNotExist());
    }

    @Test
    void recordWithBlankKeywordFailsValidation() throws Exception {
        mockAuthenticatedUser(7L);

        mockMvc.perform(post("/search-history")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"keyword\":\"   \",\"searchType\":\"keyword\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void recordWithInvalidSearchTypeFailsValidation() throws Exception {
        mockAuthenticatedUser(7L);

        mockMvc.perform(post("/search-history")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"keyword\":\"ai\",\"searchType\":\"nope\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void recordWithMissingSearchTypeDefaultsToKeyword() throws Exception {
        mockAuthenticatedUser(7L);

        mockMvc.perform(post("/search-history")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"keyword\":\"ai\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("ok"));

        verify(searchHistoryService).recordSearch(7L, "ai", "keyword");
    }

    @Test
    void deleteMissingRecordReturns404WithEnvelope() throws Exception {
        mockAuthenticatedUser(7L);
        org.mockito.Mockito.doThrow(new com.example.paperhub.common.exception.NotFoundException("搜索历史不存在或不属于当前用户"))
                .when(searchHistoryService).deleteOne(7L, 999L);

        mockMvc.perform(delete("/search-history/999")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(404))
                .andExpect(jsonPath("$.message").value("搜索历史不存在或不属于当前用户"));
    }

    @Test
    void recentKeywordsReturnsFlatKeywords() throws Exception {
        mockAuthenticatedUser(7L);
        when(searchHistoryService.getRecentKeywords(eq(7L), eq(50))).thenReturn(List.of("ai", "ml"));

        mockMvc.perform(get("/search-history/recent-keywords").param("limit", "50")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.keywords[0]").value("ai"))
                .andExpect(jsonPath("$.keywords[1]").value("ml"))
                .andExpect(jsonPath("$.count").value(2));
    }
}
