package com.example.paperhub.post.api;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.config.GlobalExceptionHandler;
import com.example.paperhub.config.JwtAuthenticationFilter;
import com.example.paperhub.config.SecurityConfig;
import com.example.paperhub.favorite.FavoriteService;
import com.example.paperhub.jwt.JwtService;
import com.example.paperhub.jwt.TokenBlacklistService;
import com.example.paperhub.like.LikeService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostMapper;
import com.example.paperhub.post.PostStatus;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.post.service.PostCrudService;
import com.example.paperhub.post.service.PostDraftService;
import com.example.paperhub.websocket.WebSocketService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = PostCrudController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class PostCrudControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PostCrudService postCrudService;
    @MockBean
    private PostDraftService postDraftService;
    @MockBean
    private LikeService likeService;
    @MockBean
    private FavoriteService favoriteService;
    @MockBean
    private PostMapper postMapper;
    @MockBean
    private WebSocketService webSocketService;
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
    void healthReturnsOk() throws Exception {
        mockMvc.perform(get("/posts/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ok"))
                .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void getPostReturnsFlatPostResp() throws Exception {
        Post post = createSamplePost(1L, "Test Title");
        when(postCrudService.findById(1L)).thenReturn(Optional.of(post));
        PostDtos.PostResp resp = createSamplePostResp();
        when(postMapper.toPostResp(eq(post), isNull())).thenReturn(resp);

        mockMvc.perform(get("/posts/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("1"))
                .andExpect(jsonPath("$.title").value("Test Title"))
                .andExpect(jsonPath("$.data").doesNotExist()); // flat, not wrapped
    }

    @Test
    void getPostNotFoundReturns404() throws Exception {
        when(postCrudService.findById(999L)).thenReturn(Optional.empty());

        mockMvc.perform(get("/posts/999").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value(404));
    }

    @Test
    void createPostWithoutAuthReturns401() throws Exception {
        mockMvc.perform(post("/posts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Test\",\"mainDiscipline\":\"工学\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void createPostReturns201() throws Exception {
        mockAuthenticatedUser(1L);
        Post post = createSamplePost(1L, "New Post");
        when(postCrudService.createPost(anyString(), anyString(), any(), anyList(), anyString(),
                any(), any(), any(), anyList(), any(), anyList(), any(), anyList(), anyList(), anyString()))
                .thenReturn(post);
        PostDtos.PostResp resp = createSamplePostResp();
        when(postMapper.toPostResp(eq(post), eq(1L))).thenReturn(resp);

        mockMvc.perform(post("/posts")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"New Post\",\"mainDiscipline\":\"工学\",\"content\":\"test\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value("1"))
                .andExpect(jsonPath("$.title").value("Test Title"));
    }

    @Test
    void deletePostWithoutAuthReturns401() throws Exception {
        mockMvc.perform(delete("/posts/1"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void deletePostReturns204() throws Exception {
        mockAuthenticatedUser(1L);
        mockMvc.perform(delete("/posts/1")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isNoContent());
        verify(postCrudService).deletePost(eq(1L), eq(1L));
    }

    @Test
    void batchGetReturnsList() throws Exception {
        Post post = createSamplePost(1L, "Batch Post");
        when(postCrudService.findById(1L)).thenReturn(Optional.of(post));
        PostDtos.PostResp resp = createSamplePostResp();
        when(postMapper.toPostResp(eq(post), isNull())).thenReturn(resp);

        mockMvc.perform(get("/posts/batch").param("ids", "1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value("1"));
    }

    @Test
    void batchGetEmptyIdsReturns400() throws Exception {
        mockMvc.perform(get("/posts/batch").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));
    }

    @Test
    void likePostWithoutAuthReturns401() throws Exception {
        mockMvc.perform(post("/posts/1/like"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void likePostReturnsLikeResp() throws Exception {
        mockAuthenticatedUser(1L);
        when(likeService.likePost(eq(1L), any())).thenReturn(true);
        when(likeService.getPostLikesCount(1L)).thenReturn(5L);
        when(likeService.isPostLiked(1L, 1L)).thenReturn(true);

        mockMvc.perform(post("/posts/1/like").header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.likesCount").value(5))
                .andExpect(jsonPath("$.isLiked").value(true));
    }

    @Test
    void favoritePostWithoutAuthReturns401() throws Exception {
        mockMvc.perform(post("/posts/1/favorite"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void saveDraftWithoutAuthReturns401() throws Exception {
        mockMvc.perform(post("/posts/1/save-draft"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void getDraftsWithoutAuthReturns401() throws Exception {
        mockMvc.perform(get("/posts/drafts"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    private Post createSamplePost(Long id, String title) {
        Post post = new Post();
        post.setId(id);
        post.setTitle(title);
        post.setContent("Sample content");
        post.setStatus(PostStatus.NORMAL);
        post.setLikesCount(0);
        post.setCommentsCount(0);
        post.setViewsCount(0);
        post.setFavoriteCount(0);
        return post;
    }

    private PostDtos.PostResp createSamplePostResp() {
        return new PostDtos.PostResp(
                "1", "Test Title", "Sample content", List.of(), "工学", List.of(), List.of(),
                new PostDtos.AuthorInfo(1L, "u@ex.com", "User", "img.png", "Uni"),
                0, 0, 0, 0, false, false, "NORMAL", null, null, true,
                null, null, null, null, null, null, null, null,
                "2025-01-01T00:00:00Z", 1.5, 800.0, 600.0
        );
    }
}
