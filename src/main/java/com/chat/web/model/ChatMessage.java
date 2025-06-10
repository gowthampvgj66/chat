package com.chat.web.model;

import java.time.Instant;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "messages")
public class ChatMessage {

    @Id
    private String id;

    private String sender;
    private String receiver;
    private String content;
    private String status; // "sent", "delivered", "seen"
    private boolean edited = false;   // to track if message was edited
    private boolean deleted = false;  //  for soft delete
    private Instant timestamp;
    private String groupId; // null for 1-1 chats, non-null for group chat
    private boolean groupMessage;
    public String getGroupId() {
		return groupId;
	}

	public void setGroupId(String groupId) {
		this.groupId = groupId;
	}

	public boolean isGroupMessage() {
		return groupMessage;
	}

	public void setGroupMessage(boolean groupMessage) {
		this.groupMessage = groupMessage;
	}

	public ChatMessage() {
        this.timestamp = Instant.now(); // default timestamp
    }

    public ChatMessage(String sender, String content, String receiver, String status) {
        this.sender = sender;
        this.content = content;
        this.receiver = receiver;
        this.status = status;
        this.edited=false;
        this.deleted = false;
        this.timestamp = Instant.now();
    }

    // Getters and Setters

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getSender() {
        return sender;
    }

    public void setSender(String sender) {
        this.sender = sender;
    }

    public String getReceiver() {
        return receiver;
    }

    public void setReceiver(String receiver) {
        this.receiver = receiver;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public boolean isEdited() {
        return edited;
    }

    public void setEdited(boolean edited) {
        this.edited = edited;
    }

    public boolean isDeleted() {
        return deleted;
    }

    public void setDeleted(boolean deleted) {
        this.deleted = deleted;
    }
}
