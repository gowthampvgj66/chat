package com.chat.web.controller;

import com.chat.web.model.ChatMessage;
import com.chat.web.model.Group;
import com.chat.web.model.MessageStatusUpdate;
import com.chat.web.model.OnlineStatus;
import com.chat.web.model.SignalMessage;
import com.chat.web.model.TypingStatus;
import com.chat.web.repo.ChatMessageRepository;
import com.chat.web.repo.GroupRepository;

import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
 
@Controller
public class ChatController {

    @Autowired
    private SimpMessagingTemplate messagingTemplate;
    @Autowired
    private ChatMessageRepository chatMessageRepository;
    @Autowired
    private GroupRepository groupRepository;
    
    @GetMapping("/chat")
    public String loadChatPage(Model model) {
        model.addAttribute("messages", chatMessageRepository.findAll()); // Pass messages to JSP
        model.addAttribute("groups", groupRepository.findAll()); //  Add groups to model
        return "index";
    }

    @MessageMapping("/sendMessage")
    public void sendMessage(@Payload ChatMessage message) {
        if (message.getSender() != null && !message.getSender().isBlank() &&
            message.getContent() != null && !message.getContent().isBlank()) {
            message.setStatus("sent"); // Initial status
            chatMessageRepository.save(message);
            messagingTemplate.convertAndSend("/topic/messages", message);
        }
    }
    @MessageMapping("/editMessage")
    public void editMessage(@Payload ChatMessage editedMessage) {
        Optional<ChatMessage> optional = chatMessageRepository.findById(editedMessage.getId());
        if (optional.isPresent()) {
            ChatMessage existing = optional.get();
            existing.setContent(editedMessage.getContent());
            existing.setEdited(true); // Set the 'edited' flag
            chatMessageRepository.save(existing);
            messagingTemplate.convertAndSend("/topic/messages", existing);
        }
    }

    @MessageMapping("/deleteMessage")
    public void deleteMessage(@Payload String messageId) {
        Optional<ChatMessage> optional = chatMessageRepository.findById(messageId);
        if (optional.isPresent()) {
            ChatMessage message = optional.get();
            message.setDeleted(true); // Mark as soft deleted
            chatMessageRepository.save(message);
            messagingTemplate.convertAndSend("/topic/messages", message);
        }
    }

    @MessageMapping("/updateStatus")
    public void updateMessageStatus(@Payload MessageStatusUpdate statusUpdate) {
        Optional<ChatMessage> optionalMessage = chatMessageRepository.findById(statusUpdate.getMessageId());
        if (optionalMessage.isPresent()) {
            ChatMessage message = optionalMessage.get();
            message.setStatus(statusUpdate.getStatus());
            chatMessageRepository.save(message);
            messagingTemplate.convertAndSend("/topic/status", statusUpdate);
        }
    }

    @MessageMapping("/typing")
    public void sendTypingStatus(@Payload TypingStatus typingStatus) {
        messagingTemplate.convertAndSend("/topic/typing", typingStatus); 
    }

    @MessageMapping("/signal")
    public void handleSignal(@Payload SignalMessage signal) {
//        if (signal.getReceiver() != null && !signal.getReceiver().isBlank()) {
//        }
        messagingTemplate.convertAndSendToUser(signal.getReceiver(), "/queue/signal", signal);

    }
    @MessageMapping("/online")
    public void sendOnlineStatus(@Payload OnlineStatus onlineStatus) {
        messagingTemplate.convertAndSend("/topic/online", onlineStatus);
    }


@MessageMapping("/createGroup")
public void createGroup(@Payload Map<String, Object> groupData) {
    String name = (String) groupData.get("name");
    List<String> members = (List<String>) groupData.get("members");
    String createdBy = (String) groupData.get("createdBy");

    Group group = new Group();
    group.setName(name);
    group.setMembers(members);
    group.setAdmins(List.of(createdBy));
    group.setCreatedBy(createdBy);
    group.setCreatedAt(new Date());

    groupRepository.save(group);

    // Notify each group member
    for (String member : members) {
        messagingTemplate.convertAndSendToUser(member, "/queue/groups", group);
    }
}
@MessageMapping("/group/sendMessage")
public void sendGroupMessage(@Payload ChatMessage message) {
    if (message.getSender() == null || message.getSender().isBlank() ||
        message.getContent() == null || message.getContent().isBlank() ||
        message.getGroupId() == null || message.getGroupId().isBlank()) {
        return; // Invalid input
    }

    message.setGroupMessage(true);
    message.setStatus("sent");
    chatMessageRepository.save(message);

    // Send to all group members via topic
    messagingTemplate.convertAndSend("/topic/group/" + message.getGroupId(), message);
}

}