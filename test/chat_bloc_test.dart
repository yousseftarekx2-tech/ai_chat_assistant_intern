import 'package:ai_chat_assistant/core/database/app_database.dart';
import 'package:ai_chat_assistant/features/chat/data/drift_chat_repository.dart';
import 'package:ai_chat_assistant/features/chat/domain/entities/chat_message.dart';
import 'package:ai_chat_assistant/features/chat/domain/entities/conversation.dart';
import 'package:ai_chat_assistant/features/chat/domain/repositories/ai_completion_repository.dart';
import 'package:ai_chat_assistant/features/chat/presentation/blocs/chat_bloc.dart';
import 'package:ai_chat_assistant/features/chat/domain/usecases/send_chat_message.dart';
import 'package:ai_chat_assistant/features/settings/domain/entities/ai_provider_config.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a pending message restored after restart can be retried', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final chatRepository = DriftChatRepository(database);
    final now = DateTime.utc(2026, 11, 21);
    final conversation = Conversation(
      id: 'conversation-pending',
      title: 'Pending conversation',
      createdAt: now,
      updatedAt: now,
    );
    final pending = ChatMessage(
      id: 'pending-stable-id',
      conversationId: conversation.id,
      role: MessageRole.user,
      content: 'Please retry me',
      createdAt: now,
      providerId: 'openai-compatible',
      status: MessageStatus.pending,
    );
    await chatRepository.saveConversation(conversation);
    await chatRepository.saveMessage(pending);

    final aiRepository = _FakeAiRepository((history) async* {
      expect(
        history.where((message) => message.role == MessageRole.user),
        hasLength(1),
      );
      yield 'Recovered reply';
    });
    final bloc = ChatBloc(chatRepository, SendChatMessage(aiRepository));
    addTearDown(() async {
      await bloc.close();
      await database.close();
    });
    final provider = AiProviderConfig(
      id: 'openai-compatible',
      name: 'Custom endpoint',
      type: AiProviderType.openAiCompatible,
      baseUrl: Uri(scheme: 'https', host: 'example.test', path: '/v1/'),
      model: 'test-model',
    );

    final loadedFuture = bloc.stream.firstWhere(
      (state) => !state.isLoading && state.messages.isNotEmpty,
    );
    bloc.add(ChatMessagesRequested(conversation.id));
    final loaded = await loadedFuture.timeout(const Duration(seconds: 5));
    expect(loaded.messages.single.status, MessageStatus.pending);

    final successFuture = bloc.stream.firstWhere(
      (state) => state.lastSentMessageId == pending.id,
    );
    bloc.add(
      ChatRetryRequested(
        message: loaded.messages.single,
        conversation: conversation,
        provider: provider,
        apiKey: 'test-only',
      ),
    );
    await successFuture.timeout(const Duration(seconds: 5));
    final saved = await chatRepository.getMessages(conversation.id);
    expect(saved, hasLength(2));
    expect(saved.first.id, pending.id);
    expect(saved.first.status, MessageStatus.sent);
    expect(saved.last.content, 'Recovered reply');
  });

  test(
    'failed request is saved locally and retry reuses its message ID',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final chatRepository = DriftChatRepository(database);
      final now = DateTime.utc(2026, 11, 21);
      final conversation = Conversation(
        id: 'conversation-1',
        title: 'Retry conversation',
        createdAt: now,
        updatedAt: now,
      );
      await chatRepository.saveConversation(conversation);

      var calls = 0;
      final aiRepository = _FakeAiRepository((history) async* {
        calls++;
        final saved = await chatRepository.getMessages(conversation.id);
        expect(saved.single.id, 'stable-message-id');
        expect(saved.single.status, MessageStatus.pending);
        if (calls == 1) throw const _OfflineException();
        yield 'Reply after retry';
      });
      final bloc = ChatBloc(chatRepository, SendChatMessage(aiRepository));
      addTearDown(() async {
        await bloc.close();
        await database.close();
      });
      final provider = AiProviderConfig(
        id: 'openai-compatible',
        name: 'Custom endpoint',
        type: AiProviderType.openAiCompatible,
        baseUrl: Uri(scheme: 'https', host: 'example.test', path: '/v1/'),
        model: 'test-model',
      );

      final failedState = bloc.stream.firstWhere(
        (state) => state.error != null,
      );
      bloc.add(
        ChatMessageSent(
          conversation: conversation,
          content: 'Hello',
          provider: provider,
          apiKey: 'test-only',
          messageId: 'stable-message-id',
        ),
      );
      final failed = await failedState.timeout(const Duration(seconds: 5));
      expect(failed.messages.single.status, MessageStatus.failed);

      final successState = bloc.stream.firstWhere(
        (state) => state.lastSentMessageId == 'stable-message-id',
      );
      bloc.add(
        ChatRetryRequested(
          message: failed.messages.single,
          conversation: conversation,
          provider: provider,
          apiKey: 'test-only',
        ),
      );
      final succeeded = await successState.timeout(const Duration(seconds: 5));
      expect(succeeded.isSending, isFalse);
      final persisted = await chatRepository.getMessages(conversation.id);
      expect(persisted, hasLength(2));
      expect(persisted.first.id, 'stable-message-id');
      expect(persisted.first.status, MessageStatus.sent);
      expect(persisted.last.content, 'Reply after retry');
    },
  );
}

class _FakeAiRepository implements AiCompletionRepository {
  const _FakeAiRepository(this._reply);
  final Stream<String> Function(List<ChatMessage> history) _reply;

  @override
  Stream<String> streamReply({
    required AiProviderConfig provider,
    required String apiKey,
    required List<ChatMessage> history,
  }) => _reply(history);
}

class _OfflineException implements Exception {
  const _OfflineException();
}
