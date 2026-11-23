import '../../../settings/domain/entities/ai_provider_config.dart';
import '../entities/chat_message.dart';

abstract interface class AiCompletionRepository {
  Stream<String> streamReply({
    required AiProviderConfig provider,
    required String apiKey,
    required List<ChatMessage> history,
  });
}
