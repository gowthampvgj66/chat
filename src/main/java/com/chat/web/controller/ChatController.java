package com.chat.web.controller;

import com.chat.web.model.ChatMessage;
import com.chat.web.model.Group;
import com.chat.web.model.MessageStatusUpdate;
import com.chat.web.model.OnlineStatus;
import com.chat.web.model.SignalMessage;
import com.chat.web.model.TypingStatus;
import com.chat.web.repo.ChatMessageRepository;
import com.chat.web.repo.GroupRepository;

import java.util.ArrayList;
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
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.ResponseBody;

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
        model.addAttribute("messages", chatMessageRepository.findAll()); // Pass all messages
        model.addAttribute("groups", groupRepository.findAll()); // Pass all groups
        return "index";
    }

    // New endpoint to fetch members of group (used in frontend)
    @GetMapping("/groups/{groupId}/members")
    @ResponseBody
    public List<String> getGroupMembers(@PathVariable String groupId) {
        return groupRepository.findById(groupId)
                .map(Group::getMembers)
                .orElse(List.of());
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
            existing.setEdited(true);
            chatMessageRepository.save(existing);
            messagingTemplate.convertAndSend("/topic/messages", existing);
        }
    }

    @MessageMapping("/deleteMessage")
    public void deleteMessage(@Payload String messageId) {
        Optional<ChatMessage> optional = chatMessageRepository.findById(messageId);
        if (optional.isPresent()) {
            ChatMessage message = optional.get();
            message.setDeleted(true);
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
            return;
        }

        message.setGroupMessage(true);
        message.setStatus("sent");
        chatMessageRepository.save(message);

        // Send to all group members via topic
        messagingTemplate.convertAndSend("/topic/group/" + message.getGroupId(), message);
    }

    @MessageMapping("/group/addMember")
    public void addMemberToGroup(@Payload Map<String, String> payload) {
        String groupId = payload.get("groupId");
        String newMember = payload.get("username");

        groupRepository.findById(groupId).ifPresent(group -> {
            // Defensive check to avoid null list
            if (group.getMembers() == null) {
                group.setMembers(new ArrayList<>());
            }

            if (!group.getMembers().contains(newMember)) {
                group.getMembers().add(newMember);
                groupRepository.save(group);

                // ✅ Notify all group members (including new one)
                for (String member : group.getMembers()) {
                    messagingTemplate.convertAndSendToUser(member, "/queue/groups", group);
                }
            }
        });
    }


    @MessageMapping("/group/removeMember")
    public void removeMemberFromGroup(@Payload Map<String, String> payload) {
        String groupId = payload.get("groupId");
        String memberToRemove = payload.get("username");

        groupRepository.findById(groupId).ifPresent(group -> {
            if (group.getMembers() == null) {
                group.setMembers(new ArrayList<>());
            }

            group.getMembers().remove(memberToRemove);
            group.getAdmins().remove(memberToRemove);
            groupRepository.save(group);

            for (String member : group.getMembers()) {
                messagingTemplate.convertAndSendToUser(member, "/queue/groups", group);
            }
        });
    }


    @MessageMapping("/group/delete")
    public void deleteGroup(@Payload Map<String, String> payload) {
        String groupId = payload.get("groupId");
        groupRepository.deleteById(groupId);
        // Could notify group members about deletion if needed
    }
}
