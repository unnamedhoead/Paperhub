package com.example.paperhub.history;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;
import java.util.stream.LongStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BrowseHistoryServiceTest {

    @Mock
    private BrowseHistoryRepository historyRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private PostRepository postRepository;

    @InjectMocks
    private BrowseHistoryService service;

    private User user;
    private Post post;

    @BeforeEach
    void setUp() {
        user = new User();
        user.setId(7L);
        post = new Post();
        post.setId(42L);
    }

    @Test
    void recordHistoryEnforcesCapByDeletingOldestBeyondLimit() {
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(postRepository.findById(42L)).thenReturn(Optional.of(post));
        when(historyRepository.findByUserAndPost(user, post)).thenReturn(Optional.empty());

        // Over capacity: 53 total rows for the user.
        when(historyRepository.countByUser(user)).thenReturn(53L);
        // ids ordered newest-first: 1..53 (id 1 newest, id 53 oldest)
        List<Long> idsNewestFirst = LongStream.rangeClosed(1, 53).boxed().toList();
        when(historyRepository.findIdsByUserOrderByViewedAtDesc(user)).thenReturn(idsNewestFirst);

        service.recordHistory(7L, 42L, "title");

        // The 3 oldest (indices 50,51,52 -> ids 51,52,53) must be deleted.
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<Long>> captor = ArgumentCaptor.forClass(List.class);
        verify(historyRepository).deleteAllByIdInBatch(captor.capture());
        assertThat(captor.getValue()).containsExactly(51L, 52L, 53L);
        assertThat(captor.getValue()).hasSize(3);
    }

    @Test
    void recordHistoryDoesNotDeleteWhenAtOrBelowCap() {
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(postRepository.findById(42L)).thenReturn(Optional.of(post));
        when(historyRepository.findByUserAndPost(user, post)).thenReturn(Optional.empty());

        // Exactly at the cap (50): nothing should be deleted.
        when(historyRepository.countByUser(user)).thenReturn(50L);

        service.recordHistory(7L, 42L, "title");

        verify(historyRepository, never()).deleteAllByIdInBatch(anyList());
        verify(historyRepository, never()).findIdsByUserOrderByViewedAtDesc(any());
    }

    @Test
    void recordHistoryUpdatesExistingRecordAndSaves() {
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(postRepository.findById(42L)).thenReturn(Optional.of(post));
        BrowseHistory existing = new BrowseHistory();
        existing.setUser(user);
        existing.setPost(post);
        when(historyRepository.findByUserAndPost(user, post)).thenReturn(Optional.of(existing));
        when(historyRepository.countByUser(user)).thenReturn(1L);

        service.recordHistory(7L, 42L, "new title");

        ArgumentCaptor<BrowseHistory> captor = ArgumentCaptor.forClass(BrowseHistory.class);
        verify(historyRepository).save(captor.capture());
        assertThat(captor.getValue().getPostTitle()).isEqualTo("new title");
        assertThat(captor.getValue().getViewedAt()).isNotNull();
    }

    @Test
    void recordHistoryFallsBackToPostTitleWhenTitleNull() {
        post.setTitle("post original title");
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(postRepository.findById(42L)).thenReturn(Optional.of(post));
        when(historyRepository.findByUserAndPost(user, post)).thenReturn(Optional.empty());
        when(historyRepository.countByUser(user)).thenReturn(1L);

        service.recordHistory(7L, 42L, null);

        ArgumentCaptor<BrowseHistory> captor = ArgumentCaptor.forClass(BrowseHistory.class);
        verify(historyRepository).save(captor.capture());
        assertThat(captor.getValue().getPostTitle()).isEqualTo("post original title");
    }

    @Test
    void recordHistoryThrowsNotFoundWhenPostMissing() {
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(postRepository.findById(42L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.recordHistory(7L, 42L, "t"))
                .isInstanceOf(NotFoundException.class);
        verify(historyRepository, never()).save(any());
    }

    @Test
    void getHistoryThrowsNotFoundWhenUserMissing() {
        when(userRepository.findById(7L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getHistory(7L, 50))
                .isInstanceOf(NotFoundException.class);
    }
}
