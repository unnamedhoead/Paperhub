package com.example.paperhub.notify;

import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

/**
 * 邮件发送服务。
 * 负责发送注册验证码、密码重置验证码等通知邮件。
 */
@Service
public class MailService {

    private static final Logger log = LoggerFactory.getLogger(MailService.class);

    private final JavaMailSender mailSender;
    private final String from;

    public MailService(JavaMailSender mailSender,
                       @Value("${spring.mail.username}") String from) {
        this.mailSender = mailSender;
        this.from = from;
    }

    public void sendVerificationMail(String to, String code) {
        send("【PaperHub注册验证码】",
                String.format("您的邮箱验证码为：%s，5分钟内有效。", code), to);
    }

    public void sendResetMail(String to, String code) {
        send("【PaperHub重置密码】",
                String.format("您的重置验证码为：%s，10分钟内有效。", code), to);
    }

    private void send(String subject, String text, String to) {
        try {
            MimeMessage msg = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(msg, true, "UTF-8");
            helper.setTo(to);
            helper.setSubject(subject);
            helper.setText(text, false);
            helper.setFrom(from);
            mailSender.send(msg);
        } catch (Exception e) {
            log.error("Failed to send mail to {}: subject=[{}], error={}", to, subject, e.getMessage());
        }
    }
}
