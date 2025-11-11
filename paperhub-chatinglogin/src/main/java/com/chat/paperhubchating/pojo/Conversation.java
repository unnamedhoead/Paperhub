
package com.chat.paperhubchating.pojo;

import jakarta.persistence.*;
import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;
import java.util.Objects;

@Entity
@Table(
    name = "chat_conversation",
    uniqueConstraints = @UniqueConstraint(columnNames = {"user1_id", "user2_id"})
)
public class Conversation implements Serializable {
    @Serial
    private static final long serialVersionUID = 1L;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "conversation_id")
    private Long id;

    @Column(name = "user1_id", nullable = false)
    private Long user1Id;

    @Column(name = "user2_id", nullable = false)
    private Long user2Id;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    @Column(name = "is_user1_online", nullable = false, columnDefinition = "TINYINT(1) DEFAULT 0")
    private Boolean isUser1Online = false;

    @Column(name = "is_user2_online", nullable = false, columnDefinition = "TINYINT(1) DEFAULT 0")
    private Boolean isUser2Online = false;

    public Conversation() {
    }

    @Override
    public String toString() {
        return "Conversation{" +
                "id=" + id +
                ", user1Id=" + user1Id +
                ", user2Id=" + user2Id +
                ", createdAt=" + createdAt +
                ", isUser1Online=" + isUser1Online +
                ", isUser2Online=" + isUser2Online +
                '}';
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getUser1Id() {
        return user1Id;
    }

    public void setUser1Id(Long user1Id) {
        this.user1Id = user1Id;
    }

    public Long getUser2Id() {
        return user2Id;
    }

    public void setUser2Id(Long user2Id) {
        this.user2Id = user2Id;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public Boolean getUser1Online() {
        return isUser1Online;
    }

    public void setUser1Online(Boolean user1Online) {
        isUser1Online = user1Online;
    }

    public Boolean getUser2Online() {
        return isUser2Online;
    }

    public void setUser2Online(Boolean user2Online) {
        isUser2Online = user2Online;
    }

    public Conversation(Long id, Long user1Id, Long user2Id, LocalDateTime createdAt, Boolean isUser1Online, Boolean isUser2Online) {
        this.id = id;
        this.user1Id = user1Id;
        this.user2Id = user2Id;
        this.createdAt = createdAt;
        this.isUser1Online = isUser1Online;
        this.isUser2Online = isUser2Online;
    }
}