import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/app_exception.dart';
import '../domain/entities/chat_message.dart';
import '../domain/entities/conversation.dart';
import '../domain/repositories/chat_repository.dart';

class DriftChatRepository implements ChatRepository {
  const DriftChatRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Conversation>> getConversations() async {
    final rows = await _database
        .customSelect('SELECT * FROM conversations ORDER BY updated_at DESC')
        .get();
    return rows.map(_conversationFromRow).toList(growable: false);
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final rows = await _database
        .customSelect(
          'SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC',
          variables: [Variable.withString(conversationId)],
        )
        .get();
    return rows.map(_messageFromRow).toList(growable: false);
  }

  @override
  Future<void> saveConversation(Conversation conversation) async {
    try {
      await _database.customStatement(
        '''INSERT INTO conversations(id,title,created_at,updated_at,provider_id)
        VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET
        title=excluded.title, updated_at=excluded.updated_at,
        provider_id=excluded.provider_id''',
        [
          conversation.id,
          conversation.title,
          conversation.createdAt.millisecondsSinceEpoch,
          conversation.updatedAt.millisecondsSinceEpoch,
          conversation.providerId,
        ],
      );
    } on Exception catch (error) {
      throw StorageException('Could not save conversation: $error');
    }
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    try {
      await _database.customStatement(
        '''INSERT INTO messages(id,conversation_id,role,content,created_at,provider_id,status)
        VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET
        content=excluded.content, status=excluded.status''',
        [
          message.id,
          message.conversationId,
          message.role.name,
          message.content,
          message.createdAt.millisecondsSinceEpoch,
          message.providerId,
          message.status.name,
        ],
      );
    } on Exception catch (error) {
      throw StorageException('Could not save message: $error');
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _database.customStatement(
        'DELETE FROM conversations WHERE id = ?',
        [conversationId],
      );
    } on Exception catch (error) {
      throw StorageException('Could not delete conversation: $error');
    }
  }

  Conversation _conversationFromRow(QueryRow row) {
    final data = row.data;
    return Conversation(
      id: data['id']! as String,
      title: data['title']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['created_at']! as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        data['updated_at']! as int,
      ),
      providerId: data['provider_id'] as String?,
    );
  }

  ChatMessage _messageFromRow(QueryRow row) {
    final data = row.data;
    return ChatMessage(
      id: data['id']! as String,
      conversationId: data['conversation_id']! as String,
      role: MessageRole.values.byName(data['role']! as String),
      content: data['content']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['created_at']! as int,
      ),
      providerId: data['provider_id'] as String?,
      status: MessageStatus.values.byName(data['status']! as String),
    );
  }
}
