import '../../../settings/domain/entities/ai_provider_config.dart';
import '../entities/chat_message.dart';
import '../repositories/ai_completion_repository.dart';

class SendChatMessage {
  const SendChatMessage(this._ai);
  final AiCompletionRepository _ai;

  Stream<String> call({
    required AiProviderConfig provider,
    required String apiKey,
    required List<ChatMessage> history,
  }) => _ai.streamReply(provider: provider, apiKey: apiKey, history: history);
}
