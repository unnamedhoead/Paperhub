package com.example.paperhub.auth;

import com.example.paperhub.common.exception.BadRequestException;
import com.example.paperhub.common.exception.ForbiddenException;
import com.example.paperhub.common.exception.NotFoundException;
import com.example.paperhub.common.exception.UnauthorizedException;
import com.example.paperhub.notify.MailService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Instant;

/**
 * 认证业务逻辑：注册、登录、邮箱验证、密码重置。
 */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    /** 邮箱验证码有效时长（秒）。 */
    static final int VERIFY_CODE_TTL_SECONDS = 5 * 60;
    /** 密码重置验证码有效时长（秒）。 */
    static final int RESET_CODE_TTL_SECONDS = 10 * 60;

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final MailService mailService;
    private final SecureRandom random = new SecureRandom();

    public AuthService(UserRepository userRepository,
                       PasswordEncoder passwordEncoder,
                       MailService mailService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.mailService = mailService;
    }

    /**
     * 注册新用户（或覆盖未验证用户的密码），并发送验证邮件。
     */
    public void register(String email, String rawPassword) {
        if (userRepository.existsByEmailAndVerified(email, true)) {
            throw new BadRequestException("该邮箱已注册，请直接登录或找回密码");
        }

        User user = userRepository.findByEmail(email).orElse(null);

        if (user != null && !user.isVerified()) {
            user.setPasswordHash(passwordEncoder.encode(rawPassword));
        } else {
            user = new User();
            user.setEmail(email);
            user.setPasswordHash(passwordEncoder.encode(rawPassword));
        }

        refreshAndSendVerificationCode(user, email);
    }

    /**
     * 重新发送验证邮件。
     */
    public void resendVerification(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new NotFoundException("邮箱未注册"));
        refreshAndSendVerificationCode(user, email);
    }

    /**
     * 生成新的验证码，设置过期时间，持久化并发送邮件。
     */
    private void refreshAndSendVerificationCode(User user, String email) {
        String code = generateCode(6);
        user.setVerifyCode(code);
        user.setVerifyExpiry(Instant.now().plusSeconds(VERIFY_CODE_TTL_SECONDS));
        userRepository.save(user);
        mailService.sendVerificationMail(email, code);
        log.info("Verification code sent to {}", email);
    }

    /**
     * 验证用户邮箱。
     */
    public void verify(String email, String code) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new NotFoundException("邮箱未注册"));
        if (user.getVerifyCode() == null || user.getVerifyExpiry() == null) {
            throw new BadRequestException("无验证请求，请先注册或重新发送验证码");
        }
        if (Instant.now().isAfter(user.getVerifyExpiry())) {
            throw new BadRequestException("验证码已过期，请重新获取验证邮件");
        }
        if (!user.getVerifyCode().equals(code)) {
            throw new BadRequestException("验证码不正确");
        }
        user.setVerified(true);
        user.setVerifyCode(null);
        user.setVerifyExpiry(null);
        userRepository.save(user);
    }

    /**
     * 校验登录凭证，通过则返回用户实体；否则 throw。
     */
    public User validateLogin(String email, String rawPassword) {
        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null) {
            throw new NotFoundException("邮箱未注册，请先注册并完成邮件验证");
        }
        if (!user.isVerified()) {
            throw new ForbiddenException("邮箱未验证，请先完成邮件验证");
        }
        if (!passwordEncoder.matches(rawPassword, user.getPasswordHash())) {
            throw new UnauthorizedException("密码错误");
        }
        return user;
    }

    /**
     * 按邮箱查找用户。
     */
    public java.util.Optional<User> findByEmail(String email) {
        return userRepository.findByEmail(email);
    }

    /**
     * 请求密码重置邮件。
     */
    public void requestReset(String email) {
        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null || !user.isVerified()) {
            throw new NotFoundException("邮箱未注册或未验证");
        }
        String code = generateCode(6);
        user.setResetCode(code);
        user.setResetExpiry(Instant.now().plusSeconds(RESET_CODE_TTL_SECONDS));
        userRepository.save(user);
        mailService.sendResetMail(email, code);
        log.info("Reset code sent to {}", email);
    }

    /**
     * 执行密码重置。
     */
    public void resetPassword(String email, String code, String newRawPassword) {
        User user = userRepository.findByEmail(email).orElse(null);
        if (user == null || !user.isVerified()) {
            throw new NotFoundException("邮箱未注册或未验证");
        }
        if (user.getResetCode() == null || user.getResetExpiry() == null) {
            throw new BadRequestException("无重置请求，请先请求重置邮件");
        }
        if (Instant.now().isAfter(user.getResetExpiry())) {
            throw new BadRequestException("重置验证码已过期，请重新发送");
        }
        if (!user.getResetCode().equals(code)) {
            throw new BadRequestException("重置验证码不正确");
        }
        user.setPasswordHash(passwordEncoder.encode(newRawPassword));
        user.setResetCode(null);
        user.setResetExpiry(null);
        userRepository.save(user);
    }

    /**
     * 生成指定长度的数字验证码。
     */
    private String generateCode(int len) {
        String digits = "0123456789";
        StringBuilder sb = new StringBuilder(len);
        for (int i = 0; i < len; i++) {
            sb.append(digits.charAt(random.nextInt(digits.length())));
        }
        return sb.toString();
    }
}
