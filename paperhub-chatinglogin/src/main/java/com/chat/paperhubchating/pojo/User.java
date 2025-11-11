package com.chat.paperhubchating.pojo;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

@Table(name="chat_user")
@Entity
public class User implements Serializable {
    @Serial
    private static final long serialVersionUID = 1L;
@Id
    private Long id;                     // user_id BIGINT PRIMARY KEY
    private String email;                // email VARCHAR(255) UNIQUE NOT NULL
    private String password;             // password VARCHAR(255) NOT NULL
    private Boolean isEmailVerified;     // is_email_verified BOOLEAN DEFAULT FALSE
    private Boolean allowPrivateMessage; // allow_private_message BOOLEAN DEFAULT TRUE
    private LocalDateTime lastOnline;    // last_online DATETIME
    // 其他用户资料字段可按需补充

    public User() {
        // 默认值与数据库默认一致
        this.isEmailVerified = Boolean.FALSE;
        this.allowPrivateMessage = Boolean.TRUE;
    }

    public User(Long id, String email, String password, Boolean isEmailVerified,
                Boolean allowPrivateMessage, LocalDateTime lastOnline) {
        this.id = id;
        this.email = email;
        this.password = password;
        this.isEmailVerified = isEmailVerified;
        this.allowPrivateMessage = allowPrivateMessage;
        this.lastOnline = lastOnline;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public Boolean getIsEmailVerified() {
        return isEmailVerified;
    }

    public void setIsEmailVerified(Boolean isEmailVerified) {
        this.isEmailVerified = isEmailVerified;
    }

    public Boolean getAllowPrivateMessage() {
        return allowPrivateMessage;
    }

    public void setAllowPrivateMessage(Boolean allowPrivateMessage) {
        this.allowPrivateMessage = allowPrivateMessage;
    }

    public LocalDateTime getLastOnline() {
        return lastOnline;
    }

    public void setLastOnline(LocalDateTime lastOnline) {
        this.lastOnline = lastOnline;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        User user = (User) o;
        return Objects.equals(id, user.id);
    }

    @Override
    public int hashCode() {
        return Objects.hashCode(id);
    }

    @Override
    public String toString() {
        return "User{" +
               "id=" + id +
               ", email='" + email + '\'' +
               ", isEmailVerified=" + isEmailVerified +
               ", allowPrivateMessage=" + allowPrivateMessage +
               ", lastOnline=" + lastOnline +
               '}';
    }
}