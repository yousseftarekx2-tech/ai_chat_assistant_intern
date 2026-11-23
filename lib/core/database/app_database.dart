import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(executor ?? driftDatabase(name: 'strix_ai'));

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''
        CREATE TABLE conversations (
          id TEXT PRIMARY KEY NOT NULL,
          title TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          provider_id TEXT
        )
      ''');
      await customStatement('''
        CREATE TABLE messages (
          id TEXT PRIMARY KEY NOT NULL,
          conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          provider_id TEXT,
          status TEXT NOT NULL DEFAULT 'sent'
        )
      ''');
      await customStatement('''
        CREATE TABLE providers (
          id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          base_url TEXT NOT NULL,
          model TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await customStatement('''
        CREATE TABLE preferences (
          key TEXT PRIMARY KEY NOT NULL,
          value TEXT NOT NULL
        )
      ''');
      await customStatement(
        'CREATE INDEX messages_conversation_time ON messages(conversation_id, created_at)',
      );
      await customStatement(
        'CREATE INDEX conversations_updated_at ON conversations(updated_at DESC)',
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
