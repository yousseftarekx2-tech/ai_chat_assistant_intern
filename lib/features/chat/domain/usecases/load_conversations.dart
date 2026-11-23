import '../entities/conversation.dart';
import '../repositories/chat_repository.dart';

class LoadConversations {
  const LoadConversations(this._repository);
  final ChatRepository _repository;

  Future<List<Conversation>> call() => _repository.getConversations();
}
