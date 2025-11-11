package com.chat.paperhubchating.pojo;



import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.io.Serializable;
import java.util.Date;


@Table(name="chat_message")
@Entity
public class Message implements Serializable {

    private static final long serialVersionUID = 1L;


    @TableId("message_id")
    @Id
    private Long messageId;

    @TableField("content")
    private String content;

    @TableField("conversation_id")
    private Long conversationId;

    @TableField("delivered_at")
    private Date deliveredAt;

    @TableField("read_at")
    private Date readAt;

    @TableField("receiver_id")
    private Long receiverId;

    @TableField("sender_id")
    private Long senderId;

    @TableField("sent_at")
    private Date sentAt;

    @TableField("status")
    private String status; // 可根据枚举类型自定义

    @Override
    public String toString() {
        return "Message{" +
                "messageId=" + messageId +
                ", content='" + content + '\'' +
                ", conversationId=" + conversationId +
                ", deliveredAt=" + deliveredAt +
                ", readAt=" + readAt +
                ", receiverId=" + receiverId +
                ", senderId=" + senderId +
                ", sentAt=" + sentAt +
                ", status='" + status + '\'' +
                '}';
    }

    public Message() {
    }

    public Message(Long messageId, String content, Long conversationId, Date deliveredAt, Date readAt, Long receiverId, Long senderId, Date sentAt, String status) {
        this.messageId = messageId;
        this.content = content;
        this.conversationId = conversationId;
        this.deliveredAt = deliveredAt;
        this.readAt = readAt;
        this.receiverId = receiverId;
        this.senderId = senderId;
        this.sentAt = sentAt;
        this.status = status;
    }

    public Long getMessageId() {
        return messageId;
    }

    public void setMessageId(Long messageId) {
        this.messageId = messageId;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public Long getConversationId() {
        return conversationId;
    }

    public void setConversationId(Long conversationId) {
        this.conversationId = conversationId;
    }

    public Date getDeliveredAt() {
        return deliveredAt;
    }

    public void setDeliveredAt(Date deliveredAt) {
        this.deliveredAt = deliveredAt;
    }

    public Date getReadAt() {
        return readAt;
    }

    public void setReadAt(Date readAt) {
        this.readAt = readAt;
    }

    public Long getReceiverId() {
        return receiverId;
    }

    public void setReceiverId(Long receiverId) {
        this.receiverId = receiverId;
    }

    public Long getSenderId() {
        return senderId;
    }

    public void setSenderId(Long senderId) {
        this.senderId = senderId;
    }

    public Date getSentAt() {
        return sentAt;
    }

    public void setSentAt(Date sentAt) {
        this.sentAt = sentAt;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}