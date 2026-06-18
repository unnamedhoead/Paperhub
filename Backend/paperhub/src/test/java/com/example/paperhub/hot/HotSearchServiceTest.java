package com.example.paperhub.hot;

import com.example.paperhub.history.SearchHistory;
import com.example.paperhub.history.SearchHistoryRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HotSearchServiceTest {

    @Mock
    private HotSearchRepository hotSearchRepository;
    @Mock
    private SearchHistoryRepository searchHistoryRepository;

    @InjectMocks
    private HotSearchService service;

    @Test
    void getLatestHotSearchesDefaultsNonPositiveLimitTo20() {
        when(hotSearchRepository.findLatestHotSearchesNative(20)).thenReturn(List.of());

        List<HotSearch> result = service.getLatestHotSearches(0);

        assertThat(result).isEmpty();
        verify(hotSearchRepository).findLatestHotSearchesNative(20);
    }

    @Test
    void getLatestHotSearchesPassesThroughPositiveLimit() {
        when(hotSearchRepository.findLatestHotSearchesNative(5)).thenReturn(List.of());

        service.getLatestHotSearches(5);

        verify(hotSearchRepository).findLatestHotSearchesNative(5);
    }

    @Test
    void calculateShortCircuitsWhenNoSearchHistoryInPeriod() {
        when(searchHistoryRepository.findByTimeRange(any(Instant.class), any(Instant.class)))
                .thenReturn(List.of());

        service.calculateAndUpdateHotSearches();

        // No persistence work when there is no input data.
        verify(hotSearchRepository, never()).saveAll(anyList());
        verify(hotSearchRepository, never()).deleteByPeriodEnd(any());
    }

    @Test
    void calculatePersistsRankingsWhenHistoryExists() {
        SearchHistory h = new SearchHistory();
        com.example.paperhub.auth.User u = new com.example.paperhub.auth.User();
        u.setId(1L);
        h.setUser(u);
        h.setKeyword("ai");
        h.setSearchType("keyword");
        h.setSearchCount(5);
        h.setUpdatedAt(Instant.now());
        when(searchHistoryRepository.findByTimeRange(any(Instant.class), any(Instant.class)))
                .thenReturn(List.of(h));
        when(hotSearchRepository.findLatestPeriodEnd()).thenReturn(null);

        service.calculateAndUpdateHotSearches();

        verify(hotSearchRepository).saveAll(anyList());
        verify(hotSearchRepository).deleteByPeriodEndBefore(any(Instant.class));
    }
}
