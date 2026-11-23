import 'dart:io';

import 'package:ai_chat_assistant/core/database/app_database.dart';
import 'package:ai_chat_assistant/features/chat/data/drift_chat_repository.dart';
import 'package:ai_chat_assistant/features/chat/domain/entities/chat_message.dart';
import 'package:ai_chat_assistant/features/chat/domain/entities/conversation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File databaseFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('strix-drift-test-');
    databaseFile = File(
      '${directory.path}${Platform.pathSeparator}chat.sqlite',
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'conversations and messages remain available after reopening database',
    () async {
      final now = DateTime.utc(2026, 11, 21);
      final firstDatabase = AppDatabase(executor: NativeDatabase(databaseFile));
      final firstRepository = DriftChatRepository(firstDatabase);
      await firstRepository.saveConversation(
        Conversation(
          id: 'conversation-1',
          title: 'Offline conversation',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await firstRepository.saveMessage(
        ChatMessage(
          id: 'message-1',
          conversationId: 'conversation-1',
          role: MessageRole.user,
          content: 'Saved before going offline',
          createdAt: now,
        ),
      );
      await firstDatabase.close();

      final reopenedDatabase = AppDatabase(
        executor: NativeDatabase(databaseFile),
      );
      final reopenedRepository = DriftChatRepository(reopenedDatabase);
      final conversations = await reopenedRepository.getConversations();
      final messages = await reopenedRepository.getMessages('conversation-1');

      expect(conversations.single.title, 'Offline conversation');
      expect(messages.single.content, 'Saved before going offline');
      await reopenedDatabase.close();
    },
  );

  test(
    'saving an existing message ID updates it without duplicating it',
    () async {
      final now = DateTime.utc(2026, 11, 21);
      final database = AppDatabase(executor: NativeDatabase.memory());
      final repository = DriftChatRepository(database);
      await repository.saveConversation(
        Conversation(
          id: 'conversation-1',
          title: 'Retry',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final message = ChatMessage(
        id: 'stable-message-id',
        conversationId: 'conversation-1',
        role: MessageRole.user,
        content: 'Retry this',
        createdAt: now,
        status: MessageStatus.pending,
      );
      await repository.saveMessage(message);
      await repository.saveMessage(
        message.copyWith(status: MessageStatus.failed),
      );

      final messages = await repository.getMessages('conversation-1');
      expect(messages, hasLength(1));
      expect(messages.single.status, MessageStatus.failed);
      await database.close();
    },
  );
}
