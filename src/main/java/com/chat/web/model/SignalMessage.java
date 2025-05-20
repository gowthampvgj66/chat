package com.chat.web.model;

public class SignalMessage {

    private String type; // "offer", "answer", "ice", "timeout", "end"
    private String sender;
    private String receiver;
    private String sdp;       // used for offer/answer
    private String candidate; // used for ICE
    private boolean videoEnabled; // whether video is enabled

    // Default constructor (important for deserialization)
    public SignalMessage() {}

    // Constructor for offer/answer/ice with video flag
    public SignalMessage(String type, String sender, String receiver, String sdpOrCandidate, boolean videoEnabled) {
        this.type = type;
        this.sender = sender;
        this.receiver = receiver;
        this.videoEnabled = videoEnabled;

        if ("offer".equals(type) || "answer".equals(type)) {
            this.sdp = sdpOrCandidate;
            this.candidate = null;
        } else if ("ice".equals(type)) {
            this.candidate = sdpOrCandidate;
            this.sdp = null;
        } else {
            this.sdp = null;
            this.candidate = null;
        }
    }

    // Constructor for "timeout", "end", and for video etc.
    public SignalMessage(String type, String sender, String receiver, String sdp, String candidate, boolean videoEnabled) {
        this.type = type;
        this.sender = sender;
        this.receiver = receiver;
        this.sdp = sdp;
        this.candidate = candidate;
        this.videoEnabled = videoEnabled;
    }

    // Getters and setters
    public String getType() {
        return type;
    }

    public void setType(String type) {
        this.type = type;
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

    public String getSdp() {
        return sdp;
    }

    public void setSdp(String sdp) {
        this.sdp = sdp;
    }

    public String getCandidate() {
        return candidate;
    }

    public void setCandidate(String candidate) {
        this.candidate = candidate;
    }

    public boolean isVideoEnabled() {
        return videoEnabled;
    }

    public void setVideoEnabled(boolean videoEnabled) {
        this.videoEnabled = videoEnabled;
    }
}
