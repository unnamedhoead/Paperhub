package com.example.paperhub.auth;

import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.notify.MailService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private PasswordEncoder passwordEncoder;
    @Mock
    private MailService mailService;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        authService = new AuthService(userRepository, passwordEncoder, mailService);
    }

    // ── register ──

    @Test
    void registerShouldCreateNewUserAndSendVerificationMail() {
        when(userRepository.existsByEmailAndVerified("a@b.com", true)).thenReturn(false);
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.empty());
        when(passwordEncoder.encode("pass")).thenReturn("hashed");

        authService.register("a@b.com", "pass");

        ArgumentCaptor<User> userCaptor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(userCaptor.capture());
        User saved = userCaptor.getValue();
        assertEquals("a@b.com", saved.getEmail());
        assertEquals("hashed", saved.getPasswordHash());
        assertFalse(saved.isVerified());
        assertNotNull(saved.getVerifyCode());
        assertNotNull(saved.getVerifyExpiry());
        verify(mailService).sendVerificationMail(eq("a@b.com"), anyString());
    }

    @Test
    void registerShouldUpdateExistingUnverifiedUser() {
        User existing = new User();
        existing.setEmail("a@b.com");
        existing.setVerified(false);

        when(userRepository.existsByEmailAndVerified("a@b.com", true)).thenReturn(false);
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(existing));
        when(passwordEncoder.encode("newpass")).thenReturn("newHashed");

        authService.register("a@b.com", "newpass");

        verify(userRepository).save(existing);
        assertEquals("newHashed", existing.getPasswordHash());
        verify(mailService).sendVerificationMail(eq("a@b.com"), anyString());
    }

    @Test
    void registerShouldThrowWhenAlreadyVerified() {
        when(userRepository.existsByEmailAndVerified("a@b.com", true)).thenReturn(true);

        assertThrows(BadRequestException.class,
                () -> authService.register("a@b.com", "pass"));
        verify(userRepository, never()).save(any());
    }

    // ── resendVerification ──

    @Test
    void resendVerificationShouldUpdateCodeAndSendMail() {
        User user = new User();
        user.setEmail("a@b.com");
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        authService.resendVerification("a@b.com");

        verify(userRepository).save(user);
        assertNotNull(user.getVerifyCode());
        verify(mailService).sendVerificationMail(eq("a@b.com"), anyString());
    }

    @Test
    void resendVerificationShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class,
                () -> authService.resendVerification("a@b.com"));
    }

    // ── verify ──

    @Test
    void verifyShouldMarkUserVerified() {
        User user = new User();
        user.setEmail("a@b.com");
        user.setVerifyCode("123456");
        user.setVerifyExpiry(Instant.now().plusSeconds(300));
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        authService.verify("a@b.com", "123456");

        assertTrue(user.isVerified());
        assertNull(user.getVerifyCode());
        assertNull(user.getVerifyExpiry());
        verify(userRepository).save(user);
    }

    @Test
    void verifyShouldThrowWhenCodeExpired() {
        User user = new User();
        user.setVerifyCode("123456");
        user.setVerifyExpiry(Instant.now().minusSeconds(1));
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        assertThrows(BadRequestException.class,
                () -> authService.verify("a@b.com", "123456"));
    }

    @Test
    void verifyShouldThrowWhenCodeWrong() {
        User user = new User();
        user.setVerifyCode("111111");
        user.setVerifyExpiry(Instant.now().plusSeconds(300));
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        assertThrows(BadRequestException.class,
                () -> authService.verify("a@b.com", "222222"));
    }

    @Test
    void verifyShouldThrowWhenNoVerificationRequest() {
        User user = new User();
        // no verifyCode or verifyExpiry set
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        assertThrows(BadRequestException.class,
                () -> authService.verify("a@b.com", "123456"));
    }

    // ── validateLogin ──

    @Test
    void validateLoginShouldReturnUserOnSuccess() {
        User user = new User();
        user.setEmail("a@b.com");
        user.setVerified(true);
        user.setPasswordHash("hashed");
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("pass", "hashed")).thenReturn(true);

        User result = authService.validateLogin("a@b.com", "pass");
        assertSame(user, result);
    }

    @Test
    void validateLoginShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class,
                () -> authService.validateLogin("a@b.com", "pass"));
    }

    @Test
    void validateLoginShouldThrowWhenNotVerified() {
        User user = new User();
        user.setVerified(false);
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        assertThrows(ForbiddenException.class,
                () -> authService.validateLogin("a@b.com", "pass"));
    }

    @Test
    void validateLoginShouldThrowWhenPasswordWrong() {
        User user = new User();
        user.setVerified(true);
        user.setPasswordHash("hashed");
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.matches("wrong", "hashed")).thenReturn(false);

        assertThrows(UnauthorizedException.class,
                () -> authService.validateLogin("a@b.com", "wrong"));
    }

    // ── requestReset ──

    @Test
    void requestResetShouldSetCodeAndSendMail() {
        User user = new User();
        user.setEmail("a@b.com");
        user.setVerified(true);
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        authService.requestReset("a@b.com");

        assertNotNull(user.getResetCode());
        assertNotNull(user.getResetExpiry());
        verify(userRepository).save(user);
        verify(mailService).sendResetMail(eq("a@b.com"), anyString());
    }

    @Test
    void requestResetShouldThrowWhenUserNotFound() {
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class,
                () -> authService.requestReset("a@b.com"));
    }

    // ── resetPassword ──

    @Test
    void resetPasswordShouldUpdatePasswordAndClearResetFields() {
        User user = new User();
        user.setVerified(true);
        user.setResetCode("654321");
        user.setResetExpiry(Instant.now().plusSeconds(600));
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));
        when(passwordEncoder.encode("newpass")).thenReturn("newHashed");

        authService.resetPassword("a@b.com", "654321", "newpass");

        assertEquals("newHashed", user.getPasswordHash());
        assertNull(user.getResetCode());
        assertNull(user.getResetExpiry());
        verify(userRepository).save(user);
    }

    @Test
    void resetPasswordShouldThrowWhenExpired() {
        User user = new User();
        user.setVerified(true);
        user.setResetCode("654321");
        user.setResetExpiry(Instant.now().minusSeconds(1));
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        assertThrows(BadRequestException.class,
                () -> authService.resetPassword("a@b.com", "654321", "newpass"));
    }

    @Test
    void resetPasswordShouldThrowWhenWrongCode() {
        User user = new User();
        user.setVerified(true);
        user.setResetCode("111111");
        user.setResetExpiry(Instant.now().plusSeconds(600));
        when(userRepository.findByEmail("a@b.com")).thenReturn(Optional.of(user));

        assertThrows(BadRequestException.class,
                () -> authService.resetPassword("a@b.com", "222222", "newpass"));
    }

    // ── TTL constants ──

    @Test
    void verifyCodeTtlShouldBe300Seconds() {
        assertEquals(300, AuthService.VERIFY_CODE_TTL_SECONDS);
    }

    @Test
    void resetCodeTtlShouldBe600Seconds() {
        assertEquals(600, AuthService.RESET_CODE_TTL_SECONDS);
    }
}
