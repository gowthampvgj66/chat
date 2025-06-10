package com.chat.web.model;

public class MessageStatusUpdate {
    private String messageId;
    private String status; // "delivered", "seen"

    public MessageStatusUpdate() {}

    public MessageStatusUpdate(String messageId, String status) {
        this.messageId = messageId;
        this.status = status;
    }

	public String getMessageId() {
		return messageId;
	}

	public void setMessageId(String messageId) {
		this.messageId = messageId;
	}

	public String getStatus() {
		return status;
	}

	public void setStatus(String status) {
		this.status = status;
	}

}
