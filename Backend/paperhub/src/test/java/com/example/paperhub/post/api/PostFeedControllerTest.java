package com.example.paperhub.post.api;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.config.GlobalExceptionHandler;
import com.example.paperhub.config.JwtAuthenticationFilter;
import com.example.paperhub.config.SecurityConfig;
import com.example.paperhub.jwt.JwtService;
import com.example.paperhub.jwt.TokenBlacklistService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostMapper;
import com.example.paperhub.post.PostStatus;
import com.example.paperhub.post.RecommendationService;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.post.service.PostFeedService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = PostFeedController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class PostFeedControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PostFeedService postFeedService;
    @MockBean
    private RecommendationService recommendationService;
    @MockBean
    private PostMapper postMapper;
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
    void getPostsReturnsFlatPostListResp() throws Exception {
        Post post = createSamplePost(1L, "Feed Post");
        Page<Post> postPage = new PageImpl<>(List.of(post));
        when(postFeedService.getPosts(eq(1), eq(20), isNull())).thenReturn(postPage);
        when(postMapper.toPostResp(eq(post), isNull())).thenReturn(createSamplePostResp());

        mockMvc.perform(get("/posts"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.posts").isArray())
                .andExpect(jsonPath("$.posts[0].id").value("1"))
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.pageSize").value(20))
                .andExpect(jsonPath("$.data").doesNotExist());
    }

    @Test
    void getPostsWithTagFilter() throws Exception {
        Post post = createSamplePost(1L, "CS Post");
        Page<Post> postPage = new PageImpl<>(List.of(post));
        when(postFeedService.getPosts(eq(1), eq(20), eq("信息科学（CS）"))).thenReturn(postPage);
        when(postMapper.toPostResp(eq(post), isNull())).thenReturn(createSamplePostResp());

        mockMvc.perform(get("/posts").param("tag", "信息科学（CS）"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.posts[0].id").value("1"));
    }

    @Test
    void getFollowingFeedWithoutAuthReturns401() throws Exception {
        mockMvc.perform(get("/posts/following").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));
    }

    @Test
    void getFollowingFeedReturnsFlatResponse() throws Exception {
        mockAuthenticatedUser(1L);
        Post post = createSamplePost(1L, "Following Post");
        Page<Post> postPage = new PageImpl<>(List.of(post));
        when(postFeedService.getFollowingFeed(eq(1L), eq(1), eq(20))).thenReturn(postPage);
        when(postMapper.toPostResp(eq(post), eq(1L))).thenReturn(createSamplePostResp());

        mockMvc.perform(get("/posts/following").header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.posts[0].id").value("1"))
                .andExpect(jsonPath("$.data").doesNotExist());
    }

    @Test
    void getRecommendationsWithoutAuthReturnsFlatResponse() throws Exception {
        Post post = createSamplePost(1L, "Rec Post");
        Page<Post> postPage = new PageImpl<>(List.of(post));
        when(postFeedService.getPosts(eq(1), eq(20))).thenReturn(postPage);
        when(postMapper.toPostResp(eq(post), isNull())).thenReturn(createSamplePostResp());

        mockMvc.perform(get("/posts/recommendations"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.posts[0].id").value("1"))
                .andExpect(jsonPath("$.data").doesNotExist());
    }

    private Post createSamplePost(Long id, String title) {
        Post post = new Post();
        post.setId(id);
        post.setTitle(title);
        post.setStatus(PostStatus.NORMAL);
        post.setLikesCount(0);
        post.setCommentsCount(0);
        post.setViewsCount(0);
        post.setFavoriteCount(0);
        return post;
    }

    private PostDtos.PostResp createSamplePostResp() {
        return new PostDtos.PostResp(
                "1", "Test Title", "", List.of(), "", List.of(), List.of(),
                new PostDtos.AuthorInfo(1L, "u@ex.com", "User", "", ""),
                0, 0, 0, 0, false, false, "NORMAL", null, null, true,
                null, null, null, null, null, null, null, null,
                "2025-01-01T00:00:00Z", 1.5, 800.0, 600.0
        );
    }
}
