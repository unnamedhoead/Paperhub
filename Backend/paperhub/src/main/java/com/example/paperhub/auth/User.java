package com.example.paperhub.auth;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

/**
 * 用户实体。
 *
 * 字段分组：
 *   (1) 认证相关 — email, passwordHash, verified, verifyCode, verifyExpiry, resetCode, resetExpiry
 *   (2) 个人资料 — name, avatar, affiliation, bio, researchDirections, profileBackground
 *   (3) 角色与状态 — role, status, muteUntil
 *   (4) 隐私设置 — hideFollowing, hideFollowers, publicFavorites
 */
@Entity
@Table(name = "users", indexes = {
        @Index(name = "idx_email", columnList = "email", unique = true)
})
@Getter
@Setter
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id")
    private Long id;

    // ──────────────────── (1) 认证相关 ────────────────────

    @Column(name = "email", nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "verified", nullable = false)
    private boolean verified = false;

    @Column(name = "verify_code")
    private String verifyCode;

    @Column(name = "verify_expiry")
    private Instant verifyExpiry;

    @Column(name = "reset_code")
    private String resetCode;

    @Column(name = "reset_expiry")
    private Instant resetExpiry;

    // ──────────────────── (2) 个人资料 ────────────────────

    @Column(name = "name")
    private String name;

    @Column(name = "avatar")
    private String avatar;

    @Column(name = "affiliation")
    private String affiliation;

    @Column(name = "bio", columnDefinition = "TEXT")
    private String bio;

    @Column(name = "research_directions", columnDefinition = "TEXT")
    private String researchDirections;

    @Column(name = "profile_background")
    private String profileBackground;

    // ──────────────────── (3) 角色与状态 ────────────────────

    @Enumerated(EnumType.STRING)
    @Column(name = "role", nullable = false, columnDefinition = "varchar(20) default 'USER'")
    private UserRole role = UserRole.USER;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false,
            columnDefinition = "ENUM('NORMAL','BANNED','MUTE','AUDIT') CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci DEFAULT 'NORMAL'")
    private UserStatus status = UserStatus.NORMAL;

    /**
     * 禁言截止时间（可为空，空表示不限期）。
     */
    @Column(name = "mute_until")
    private Instant muteUntil;

    // ──────────────────── (4) 隐私设置 ────────────────────

    /** 是否隐藏关注列表（true 时除本人外他人无法查看其关注列表）。 */
    @Column(name = "hide_following", nullable = false)
    private boolean hideFollowing = false;

    /** 是否隐藏粉丝列表（true 时除本人外他人无法查看其粉丝列表）。 */
    @Column(name = "hide_followers", nullable = false)
    private boolean hideFollowers = false;

    /** 收藏是否公开（false 时除本人外他人无法查看其收藏列表）。 */
    @Column(name = "public_favorites", nullable = false)
    private boolean publicFavorites = true;
}
