package com.example.paperhub.jwt;

import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;

class JwtServiceTest {
    private static final String SECRET = "12345678901234567890123456789012";

    @Test
    void generateTokenIncludesAccessTypeAndUserId() {
        JwtService jwtService = new JwtService(SECRET, 1800, 604800);

        String token = jwtService.generateToken("user@example.com", 42L);
        Optional<Claims> claims = jwtService.parseTokenSafely(token);

        assertThat(jwtService.validateToken(token)).isTrue();
        assertThat(claims).isPresent();
        assertThat(claims.get().getSubject()).isEqualTo("user@example.com");
        assertThat(claims.get().get(JwtService.TOKEN_TYPE_CLAIM, String.class))
                .isEqualTo(JwtService.TOKEN_TYPE_ACCESS);
        assertThat(jwtService.extractUserId(token)).contains(42L);
    }

    @Test
    void refreshTokenIsNotAcceptedAsAccessToken() {
        JwtService jwtService = new JwtService(SECRET, 1800, 604800);

        String refreshToken = jwtService.generateRefreshToken("user@example.com", 42L);
        Optional<Claims> claims = jwtService.parseTokenSafely(refreshToken);

        assertThat(claims).isPresent();
        assertThat(claims.get().get(JwtService.TOKEN_TYPE_CLAIM, String.class))
                .isEqualTo(JwtService.TOKEN_TYPE_REFRESH);
        assertThat(jwtService.validateRefreshToken(refreshToken)).isTrue();
        assertThat(jwtService.validateToken(refreshToken)).isFalse();
        assertThat(jwtService.extractEmail(refreshToken)).isEqualTo("user@example.com");
        assertThat(jwtService.extractExpiration(refreshToken)).isPresent();
    }

    @Test
    void invalidTokenReturnsEmptyClaims() {
        JwtService jwtService = new JwtService(SECRET, 1800, 604800);

        assertThat(jwtService.parseTokenSafely("invalid")).isEmpty();
        assertThat(jwtService.validateToken("invalid")).isFalse();
        assertThat(jwtService.validateRefreshToken("invalid")).isFalse();
    }

    @Test
    void tokenWithoutUserIdStillValidatesForBackwardCompatibleCallers() {
        JwtService jwtService = new JwtService(SECRET, 1800, 604800);

        String token = jwtService.generateToken("legacy@example.com");

        assertThat(jwtService.validateToken(token)).isTrue();
        assertThat(jwtService.extractEmail(token)).isEqualTo("legacy@example.com");
        assertThat(jwtService.extractUserId(token)).isEmpty();
    }
}
