package com.chat.web.repo;

import com.chat.web.model.ChatMessage;

import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;

public interface ChatMessageRepository extends MongoRepository<ChatMessage, String> {
	  List<ChatMessage> findByReceiver(String receiver);
	    List<ChatMessage> findBySender(String sender);
	    List<ChatMessage> findBySenderAndReceiverOrReceiverAndSenderOrderByTimestampAsc(
	            String sender1, String receiver1, String sender2, String receiver2
	    );
}