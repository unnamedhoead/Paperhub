//JWT模块，负责生成和验证JWT令牌，具体内容就是在用户登录之后生成一个JWT令牌，在后续该用户发请求的时候就使用这个JWT令牌进行身份验证
//如果后续添加的模块实现的都是用户登录之后才能使用的功能，那么jwt无需修改，只需要在后续的模块中使用JwtService生成JWT令牌并进行身份验证即可
package com.example.paperhub.jwt;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import java.util.UUID;

@Service//定义服务层
public class JwtService {
    public static final String BEARER_PREFIX = "Bearer ";
    public static final String TOKEN_TYPE_CLAIM = "type";
    public static final String TOKEN_TYPE_ACCESS = "access";
    public static final String TOKEN_TYPE_REFRESH = "refresh";
    public static final String USER_ID_CLAIM = "userId";
    public static final String JTI_CLAIM = "jti";

    private final SecretKey key;
    private final long expiresInSeconds;
    private final long refreshExpiresInSeconds;

    public JwtService(
        @Value("${jwt.secret}") String secret,
        @Value("${jwt.expires-in-seconds:3600}") long expiresInSeconds,
        @Value("${jwt.refresh-expires-in-seconds:604800}") long refreshExpiresInSeconds
    ) {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("jwt.secret must be configured");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes());
        this.expiresInSeconds = expiresInSeconds;
        this.refreshExpiresInSeconds = refreshExpiresInSeconds;
    }

    /**
     * 生成Access Token（短期令牌，用于API请求）
     */
    public String generateToken(String subject) {
        return generateToken(subject, null);
    }

    public String generateToken(String subject, Long userId) {
        return buildToken(subject, userId, TOKEN_TYPE_ACCESS, expiresInSeconds);
    }

    /**
     * 生成Refresh Token（长期令牌，用于刷新Access Token）
     */
    public String generateRefreshToken(String subject) {
        return generateRefreshToken(subject, null);
    }

    public String generateRefreshToken(String subject, Long userId) {
        return buildToken(subject, userId, TOKEN_TYPE_REFRESH, refreshExpiresInSeconds);
    }

    private String buildToken(String subject, Long userId, String tokenType, long ttlSeconds) {
        Instant now = Instant.now();
        var builder = Jwts.builder()
            .setSubject(subject)
            .setIssuedAt(Date.from(now))
            .setExpiration(Date.from(now.plusSeconds(ttlSeconds)))
            .setId(UUID.randomUUID().toString())
            .claim(TOKEN_TYPE_CLAIM, tokenType)
            .claim(JTI_CLAIM, UUID.randomUUID().toString());
        if (userId != null) {
            builder.claim(USER_ID_CLAIM, userId);
        }
        return builder.signWith(key, SignatureAlgorithm.HS256).compact();
    }

    public long getExpiresInSeconds() {
        return expiresInSeconds;
    }

    public long getRefreshExpiresInSeconds() {
        return refreshExpiresInSeconds;
    }

    /**
     * 验证并解析JWT token
     * @param token JWT token
     * @return Claims对象，包含token中的所有信息
     * @throws io.jsonwebtoken.JwtException 如果token无效或已过期
     */
    private Claims parseToken(String token) {
        return Jwts.parserBuilder()
            .setSigningKey(key)
            .build()
            .parseClaimsJws(token)
            .getBody();
    }

    public Optional<Claims> parseTokenSafely(String token) {
        try {
            return Optional.of(parseToken(token));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    /**
     * 从token中提取email（subject）
     * @param token JWT token
     * @return email地址
     */
    public String extractEmail(String token) {
        Claims claims = parseToken(token);
        return claims.getSubject();
    }

    /**
     * 验证token是否有效
     * @param token JWT token
     * @return true if valid, false otherwise
     */
    public boolean validateToken(String token) {
        return parseTokenSafely(token)
                .map(claims -> TOKEN_TYPE_ACCESS.equals(claims.get(TOKEN_TYPE_CLAIM, String.class)))
                .orElse(false);
    }

    /**
     * 验证refresh token是否有效
     * @param token Refresh token
     * @return true if valid, false otherwise
     */
    public boolean validateRefreshToken(String token) {
        return parseTokenSafely(token)
                .map(claims -> TOKEN_TYPE_REFRESH.equals(claims.get(TOKEN_TYPE_CLAIM, String.class)))
                .orElse(false);
    }

    public Optional<Instant> extractExpiration(String token) {
        return parseTokenSafely(token)
                .map(Claims::getExpiration)
                .map(Date::toInstant);
    }

    public Optional<Long> extractUserId(String token) {
        return parseTokenSafely(token)
                .map(claims -> claims.get(USER_ID_CLAIM, Number.class))
                .map(Number::longValue);
    }
}


