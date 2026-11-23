enum MessageRole { user, assistant, system }

enum MessageStatus { pending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.providerId,
    this.status = MessageStatus.sent,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime createdAt;
  final String? providerId;
  final MessageStatus status;

  ChatMessage copyWith({String? content, MessageStatus? status}) => ChatMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    content: content ?? this.content,
    createdAt: createdAt,
    providerId: providerId,
    status: status ?? this.status,
  );
}
