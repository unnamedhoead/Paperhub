package com.example.paperhub.config;

import com.example.paperhub.auth.User;
import com.example.paperhub.auth.UserRepository;
import com.example.paperhub.auth.UserRole;
import com.example.paperhub.jwt.JwtService;
import com.example.paperhub.jwt.TokenBlacklistService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;
import java.util.Optional;

/**
 * JWT认证过滤器
 * 从请求头中提取JWT token，验证后设置SecurityContext
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(JwtAuthenticationFilter.class);

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final TokenBlacklistService tokenBlacklistService;

    public JwtAuthenticationFilter(
            JwtService jwtService,
            UserRepository userRepository,
            TokenBlacklistService tokenBlacklistService
    ) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.tokenBlacklistService = tokenBlacklistService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");
        
        if (authHeader != null && authHeader.startsWith(JwtService.BEARER_PREFIX)) {
            String token = authHeader.substring(JwtService.BEARER_PREFIX.length());
            
            try {
                if (jwtService.validateToken(token) && !isBlacklisted(token)) {
                    String email = jwtService.extractEmail(token);
                    Optional<User> userOpt = userRepository.findByEmail(email);
                    
                    if (userOpt.isPresent() && userOpt.get().isVerified()) {
                        User user = userOpt.get();
                        UserRole role = user.getRole() != null ? user.getRole() : UserRole.USER;
                        
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(
                                        user,
                                        null,
                                        Collections.singletonList(new SimpleGrantedAuthority("ROLE_" + role.name()))
                                );
                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    }
                }
            } catch (Exception e) {
                log.warn("JWT authentication failed: {}", e.getMessage());
                SecurityContextHolder.clearContext();
            }
        }
        
        filterChain.doFilter(request, response);
    }

    private boolean isBlacklisted(String token) {
        try {
            return tokenBlacklistService.isBlacklisted(token);
        } catch (Exception e) {
            log.warn("JWT blacklist check failed: {}", e.getMessage());
            return false;
        }
    }
}

