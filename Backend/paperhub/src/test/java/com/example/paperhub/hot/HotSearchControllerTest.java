package com.example.paperhub.hot;

import com.example.paperhub.auth.UserRepository;
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
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Slice test for {@link HotSearchController}: flat JSON shape with the exact field names the
 * Flutter frontend reads (rank/keyword/searchType/heat/tag), plus the type filter and empty list.
 */
@WebMvcTest(controllers = HotSearchController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class HotSearchControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private HotSearchService hotSearchService;

    @MockBean
    private JwtService jwtService;
    @MockBean
    private UserRepository userRepository;
    @MockBean
    private TokenBlacklistService tokenBlacklistService;

    private HotSearch sample(String keyword, String type, double heat, int rank, String tag) {
        HotSearch hs = new HotSearch(
                keyword, type, heat, rank, 10L, 5L,
                Instant.parse("2025-01-01T00:00:00Z"),
                Instant.parse("2025-01-02T00:00:00Z"));
        hs.setTag(tag);
        hs.setGrowthRate(1.8);
        return hs;
    }

    @Test
    void getHotSearchesReturnsFlatItemsWithHeatField() throws Exception {
        when(hotSearchService.getLatestHotSearches(anyInt()))
                .thenReturn(List.of(sample("深度学习", "keyword", 125.6, 1, "热")));

        mockMvc.perform(get("/hot-searches").param("limit", "20"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].rank").value(1))
                .andExpect(jsonPath("$.items[0].keyword").value("深度学习"))
                .andExpect(jsonPath("$.items[0].searchType").value("keyword"))
                // field is "heat" (mapped from heatScore), matching search_screen.dart
                .andExpect(jsonPath("$.items[0].heat").value(125.6))
                .andExpect(jsonPath("$.items[0].tag").value("热"))
                .andExpect(jsonPath("$.count").value(1))
                .andExpect(jsonPath("$.periodEnd").value("2025-01-02T00:00:00Z"))
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.data").doesNotExist());
    }

    @Test
    void getHotSearchesFiltersBySearchType() throws Exception {
        when(hotSearchService.getLatestHotSearches(anyInt())).thenReturn(List.of(
                sample("a", "keyword", 10.0, 1, null),
                sample("b", "tag", 9.0, 2, null)));

        mockMvc.perform(get("/hot-searches").param("type", "tag"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(1))
                .andExpect(jsonPath("$.items[0].keyword").value("b"))
                .andExpect(jsonPath("$.items[0].searchType").value("tag"));
    }

    @Test
    void getHotSearchesEmptyListStillReturnsTimestampAndPeriodEnd() throws Exception {
        when(hotSearchService.getLatestHotSearches(anyInt())).thenReturn(List.of());

        mockMvc.perform(get("/hot-searches"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.count").value(0))
                .andExpect(jsonPath("$.periodEnd").exists())
                .andExpect(jsonPath("$.timestamp").exists());
    }
}
