import 'package:ai_chat_assistant/core/database/app_database.dart';
import 'package:ai_chat_assistant/features/chat/data/drift_chat_repository.dart';
import 'package:ai_chat_assistant/features/chat/domain/entities/chat_message.dart';
import 'package:ai_chat_assistant/features/chat/presentation/blocs/conversation_bloc.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConversationBloc creates, opens, and deletes a conversation', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    final repository = DriftChatRepository(database);
    final bloc = ConversationBloc(repository);
    addTearDown(() async {
      await bloc.close();
      await database.close();
    });

    final createdFuture = bloc.stream.firstWhere(
      (state) => state is ConversationLoaded && state.conversations.length == 1,
    );
    bloc.add(const ConversationCreated(title: 'Working notes'));
    final created = await createdFuture.timeout(const Duration(seconds: 5));
    final conversation = created.selected!;
    expect(conversation.title, 'Working notes');

    await repository.saveMessage(
      ChatMessage(
        id: 'message-1',
        conversationId: conversation.id,
        role: MessageRole.user,
        content: 'Keep this local',
        createdAt: DateTime.now(),
      ),
    );

    final secondConversationFuture = bloc.stream.firstWhere(
      (state) => state is ConversationLoaded && state.conversations.length == 2,
    );
    bloc.add(const ConversationCreated(title: 'Another chat'));
    await secondConversationFuture.timeout(const Duration(seconds: 5));

    final openedFuture = bloc.stream.firstWhere(
      (state) =>
          state is ConversationLoaded && state.selected?.id == conversation.id,
    );
    bloc.add(ConversationOpened(conversation));
    expect(
      (await openedFuture.timeout(const Duration(seconds: 5))).selected?.id,
      conversation.id,
    );

    final deletedFuture = bloc.stream.firstWhere(
      (state) =>
          state is ConversationLoaded &&
          state.conversations.length == 1 &&
          state.selected == null,
    );
    bloc.add(ConversationDeleted(conversation.id));
    await deletedFuture.timeout(const Duration(seconds: 5));
    expect(await repository.getMessages(conversation.id), isEmpty);
  });
}
