package com.example.paperhub.post.api;

import com.example.paperhub.config.GlobalExceptionHandler;
import com.example.paperhub.config.JwtAuthenticationFilter;
import com.example.paperhub.config.SecurityConfig;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostMapper;
import com.example.paperhub.post.PostStatus;
import com.example.paperhub.post.dto.PostDtos;
import com.example.paperhub.post.service.PostSearchService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = PostSearchController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class PostSearchControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PostSearchService postSearchService;
    @MockBean
    private PostMapper postMapper;
    // Required for SecurityConfig
    @MockBean
    private com.example.paperhub.jwt.JwtService jwtService;
    @MockBean
    private com.example.paperhub.auth.UserRepository userRepository;
    @MockBean
    private com.example.paperhub.jwt.TokenBlacklistService tokenBlacklistService;

    @Test
    void searchPostsReturnsFlatResponse() throws Exception {
        Post post = createSamplePost(1L, "Deep Learning");
        Page<Post> postPage = new PageImpl<>(List.of(post));
        when(postSearchService.searchPosts(eq("deep learning"), eq("keyword"), eq("hot"), eq(1), eq(20)))
                .thenReturn(postPage);
        when(postMapper.toPostResp(eq(post), isNull())).thenReturn(createSamplePostResp());

        mockMvc.perform(get("/posts/search").param("q", "deep learning"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.posts").isArray())
                .andExpect(jsonPath("$.posts[0].id").value("1"))
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.data").doesNotExist());
    }

    @Test
    void searchPostsByTagSortNew() throws Exception {
        Post post = createSamplePost(1L, "Tagged Post");
        Page<Post> postPage = new PageImpl<>(List.of(post));
        when(postSearchService.searchPosts(eq("ai"), eq("tag"), eq("new"), eq(2), eq(10)))
                .thenReturn(postPage);
        when(postMapper.toPostResp(eq(post), isNull())).thenReturn(createSamplePostResp());

        mockMvc.perform(get("/posts/search")
                        .param("q", "ai")
                        .param("type", "tag")
                        .param("sort", "new")
                        .param("page", "2")
                        .param("pageSize", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(2))
                .andExpect(jsonPath("$.pageSize").value(10));
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
