package com.chat.web.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

import com.chat.web.model.ChatMessage;
import com.chat.web.model.SignalMessage;
import com.chat.web.model.TypingStatus;
import com.chat.web.repo.ChatMessageRepository;

@Controller
public class ChatController {

    @Autowired
    private SimpMessagingTemplate messagingTemplate;

    @Autowired
    private ChatMessageRepository chatMessageRepository;

    @GetMapping("/chat")
    public String loadChatPage() {
        return "index"; 
    }

    @MessageMapping("/sendMessage")
    public void sendMessage(@Payload ChatMessage message) {
        chatMessageRepository.save(message);
        messagingTemplate.convertAndSend("/topic/messages", message);
    } 

    @MessageMapping("/typing")
    public void userTyping(@Payload TypingStatus status) {
        messagingTemplate.convertAndSend("/topic/typing", status);
    }

    @MessageMapping("/signal")
    public void signaling(@Payload SignalMessage message) {
        // this will send signal message to the receiver
        messagingTemplate.convertAndSendToUser(
            message.getReceiver(), "/queue/signal", message
        );

        // This loop is for timeout 
        if ("offer".equals(message.getType())) {
            new Thread(() -> {
                try {
                    Thread.sleep(30000); // this make call to set for 30 seconds
                    messagingTemplate.convertAndSendToUser(
                        message.getSender(), "/queue/signal",
                        new SignalMessage("timeout", message.getSender(), message.getReceiver(), "", null, message.isVideoEnabled())
                    );
                } catch (InterruptedException ignored) {}
            }).start();
        }

        // This loop is for end call
        if ("end".equals(message.getType())) {
            messagingTemplate.convertAndSendToUser(
                message.getReceiver(), "/queue/signal",
                new SignalMessage("end", message.getSender(), message.getReceiver(), "", null, message.isVideoEnabled())
            );
        }
    }
}
