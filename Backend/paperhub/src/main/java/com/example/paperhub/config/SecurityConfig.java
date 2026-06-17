package com.example.paperhub.config;

import com.example.paperhub.common.dto.ApiResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {
    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final ObjectMapper objectMapper;
    private final List<String> allowedOrigins;

    public SecurityConfig(
            JwtAuthenticationFilter jwtAuthenticationFilter,
            ObjectMapper objectMapper,
            @Value("${app.cors.allowed-origins:*}") String allowedOrigins
    ) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
        this.objectMapper = objectMapper;
        this.allowedOrigins = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .toList();
    }

    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(cors -> cors.configurationSource(request -> {
                    CorsConfiguration cfg = new CorsConfiguration();
                    if (allowedOrigins.contains("*")) {
                        cfg.setAllowedOriginPatterns(List.of("*"));
                    } else {
                        cfg.setAllowedOrigins(allowedOrigins);
                    }
                    cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
                    cfg.setAllowedHeaders(List.of("*"));
                    cfg.setExposedHeaders(List.of("Authorization"));
                    cfg.setAllowCredentials(false);
                    return cfg;
                }))
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((request, response, authException) ->
                                writeError(response, HttpServletResponse.SC_UNAUTHORIZED, "未认证，请先登录"))
                        .accessDeniedHandler((request, response, accessDeniedException) ->
                                writeError(response, HttpServletResponse.SC_FORBIDDEN, "权限不足"))
                )
                .authorizeHttpRequests(reg -> reg
                        // CORS 预检
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        // 完全公开：认证入口、arXiv 代理、健康检查
                        .requestMatchers("/auth/**", "/arxiv/**", "/posts/health").permitAll()
                        // 管理后台：角色校验
                        .requestMatchers("/admin/**", "/api/admin/**").hasAnyRole("ADMIN", "SUPER_ADMIN")
                        // 私有数据域：任何方法都要登录（个人历史/通知/聊天/上传/举报/我的资料）
                        .requestMatchers(
                                "/browse-history/**", "/search-history/**", "/notifications/**",
                                "/api/conversations/**", "/api/upload/**", "/api/report/**",
                                "/users/me", "/users/me/**"
                        ).authenticated()
                        // 公开内容读取：匿名可浏览帖子/评论/他人资料/热搜（GET）
                        .requestMatchers(HttpMethod.GET, "/posts/**", "/users/**", "/hot-searches/**").permitAll()
                        // 其余写操作（点赞/收藏/关注/评论/发帖/编辑/删除…）一律要登录
                        .requestMatchers(HttpMethod.POST, "/**").authenticated()
                        .requestMatchers(HttpMethod.PUT, "/**").authenticated()
                        .requestMatchers(HttpMethod.DELETE, "/**").authenticated()
                        // 默认拒绝匿名（不再 permitAll 兜底）
                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);


        return http.build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    private void writeError(HttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json;charset=UTF-8");
        objectMapper.writeValue(response.getWriter(), ApiResponse.error(status, message));
    }
}
