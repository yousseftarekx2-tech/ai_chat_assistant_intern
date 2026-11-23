import '../entities/chat_message.dart';
import '../entities/conversation.dart';

abstract interface class ChatRepository {
  Future<List<Conversation>> getConversations();
  Future<List<ChatMessage>> getMessages(String conversationId);
  Future<void> saveConversation(Conversation conversation);
  Future<void> saveMessage(ChatMessage message);
  Future<void> deleteConversation(String conversationId);
}
