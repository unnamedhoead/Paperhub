package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.common.exception.NotFoundException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SearchHistoryServiceTest {

    @Mock
    private SearchHistoryRepository searchHistoryRepository;
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private SearchHistoryService service;

    private User user;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(7L);
    }

    @Test
    void recordSearchCreatesNewRecordTrimmingKeyword() {
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(searchHistoryRepository.findByUserAndKeywordAndSearchType(user, "ai", "keyword"))
                .thenReturn(Optional.empty());
        when(searchHistoryRepository.countByUserId(7L)).thenReturn(1L);

        service.recordSearch(7L, "  ai  ", "keyword");

        ArgumentCaptor<SearchHistory> captor = ArgumentCaptor.forClass(SearchHistory.class);
        verify(searchHistoryRepository).save(captor.capture());
        SearchHistory saved = captor.getValue();
        assertThat(saved.getKeyword()).isEqualTo("ai"); // trimmed
        assertThat(saved.getSearchType()).isEqualTo("keyword");
        // Behavior-preserving: a new SearchHistory defaults searchCount=1 and recordSearch
        // increments once, so the first record persists with count 2 (pre-existing behavior).
        assertThat(saved.getSearchCount()).isEqualTo(2);
    }

    @Test
    void recordSearchIncrementsCountForExistingRecord() {
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        SearchHistory existing = new SearchHistory();
        existing.setUser(user);
        existing.setKeyword("ai");
        existing.setSearchType("keyword");
        existing.setSearchCount(4);
        when(searchHistoryRepository.findByUserAndKeywordAndSearchType(user, "ai", "keyword"))
                .thenReturn(Optional.of(existing));
        when(searchHistoryRepository.countByUserId(7L)).thenReturn(1L);

        service.recordSearch(7L, "ai", "keyword");

        ArgumentCaptor<SearchHistory> captor = ArgumentCaptor.forClass(SearchHistory.class);
        verify(searchHistoryRepository).save(captor.capture());
        assertThat(captor.getValue().getSearchCount()).isEqualTo(5);
    }

    @Test
    void recordSearchIgnoresBlankKeywordSilently() {
        service.recordSearch(7L, "   ", "keyword");
        verify(searchHistoryRepository, never()).save(any());
        verify(userRepository, never()).findById(any());
    }

    @Test
    void deleteOneThrowsNotFoundWhenNothingDeleted() {
        when(searchHistoryRepository.deleteByIdAndUserId(999L, 7L)).thenReturn(0);

        assertThatThrownBy(() -> service.deleteOne(7L, 999L))
                .isInstanceOf(NotFoundException.class);
    }

    @Test
    void deleteOneSucceedsWhenRowDeleted() {
        when(searchHistoryRepository.deleteByIdAndUserId(5L, 7L)).thenReturn(1);

        service.deleteOne(7L, 5L); // no exception
        verify(searchHistoryRepository).deleteByIdAndUserId(5L, 7L);
    }
}
