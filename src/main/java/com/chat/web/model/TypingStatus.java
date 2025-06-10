package com.chat.web.model;

public class TypingStatus {
    private String sender;
    private boolean isTyping;

    public TypingStatus() {}

    public TypingStatus(String sender, boolean isTyping) {
        this.sender = sender;
        this.isTyping = isTyping;
    }

    public String getSender() {
        return sender;
    }

    public void setSender(String sender) {
        this.sender = sender;
    }

    public boolean isTyping() {
        return isTyping;
    }

    public void setTyping(boolean typing) {
        isTyping = typing;
    }
   
}
