package com.example.paperhub.report;

import com.example.paperhub.admin.ReportStatus;
import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.config.GlobalExceptionHandler;
import com.example.paperhub.config.JwtAuthenticationFilter;
import com.example.paperhub.config.SecurityConfig;
import com.example.paperhub.jwt.JwtService;
import com.example.paperhub.jwt.TokenBlacklistService;
import com.example.paperhub.post.Post;
import com.example.paperhub.post.PostStatus;
import com.example.paperhub.report.dto.PostDetailResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = ReportPostController.class)
@Import({SecurityConfig.class, JwtAuthenticationFilter.class, GlobalExceptionHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origins=*")
class ReportPostControllerTest {

    @Autowired private MockMvc mockMvc;
    @MockBean private ReportPostUserService reportPostUserService;
    @MockBean private JwtService jwtService;
    @MockBean private UserRepository userRepository;
    @MockBean private TokenBlacklistService tokenBlacklistService;

    private static final String TOKEN = "valid-token";

    private void mockUser() {
        User u = new User();
        u.setId(5L);
        u.setEmail("user@test.com");
        u.setName("TestUser");
        u.setVerified(true);
        u.setRole(UserRole.USER);
        when(jwtService.validateToken(TOKEN)).thenReturn(true);
        when(tokenBlacklistService.isBlacklisted(TOKEN)).thenReturn(false);
        when(jwtService.extractEmail(TOKEN)).thenReturn(u.getEmail());
        when(userRepository.findByEmail(u.getEmail())).thenReturn(Optional.of(u));
    }

    @Test
    void reportPostAsAuthenticatedUserReturnsResponse() throws Exception {
        mockUser();
        Post post = new Post();
        post.setId(42L);
        post.setTitle("Test Post");
        User author = new User();
        author.setId(99L);
        post.setAuthor(author);

        ReportPost report = new ReportPost();
        report.setId(1L);
        report.setReporter(new User() {{ setId(5L); setName("TestUser"); }});
        report.setPost(post);
        report.setDescription("违规内容");
        report.setStatus(ReportStatus.PENDING);
        report.setReportTime(Instant.now());

        when(reportPostUserService.reportPost(eq(42L), eq("违规内容"), any()))
                .thenReturn(report);

        mockMvc.perform(post("/api/report/post")
                        .header("Authorization", "Bearer " + TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"postId\":42,\"description\":\"违规内容\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andExpect(jsonPath("$.message").value("举报成功，我们会尽快处理"));
    }

    @Test
    void getPostDetailReturnsVisiblePostForAuthor() throws Exception {
        mockUser();
        PostDetailResponse detail = new PostDetailResponse(
                1L, "Title", "Content", null, null,
                5L, "TestUser", "NORMAL", null,
                true, true, "正常",
                Instant.now(), Instant.now()
        );
        when(reportPostUserService.getPostDetail(eq(1L), any())).thenReturn(detail);

        mockMvc.perform(get("/api/post/1")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.visible").value(true))
                .andExpect(jsonPath("$.canEdit").value(true));
    }

    @Test
    void getPostDetailReturns403WhenNotVisible() throws Exception {
        mockUser();
        PostDetailResponse detail = new PostDetailResponse(
                1L, "Title", "Content", null, null,
                99L, "Other", "REMOVED", "违规",
                false, false, "该帖子已被下架",
                Instant.now(), Instant.now()
        );
        when(reportPostUserService.getPostDetail(eq(1L), any())).thenReturn(detail);

        mockMvc.perform(get("/api/post/1")
                        .header("Authorization", "Bearer " + TOKEN))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.success").value(false));
    }
}
