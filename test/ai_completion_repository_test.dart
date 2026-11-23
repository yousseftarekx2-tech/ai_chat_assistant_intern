import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_chat_assistant/features/chat/data/dio_ai_completion_repository.dart';
import 'package:ai_chat_assistant/features/chat/domain/entities/chat_message.dart';
import 'package:ai_chat_assistant/features/settings/domain/entities/ai_provider_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final history = [
    ChatMessage(
      id: 'user-1',
      conversationId: 'conversation-1',
      role: MessageRole.user,
      content: 'Explain Drift briefly',
      createdAt: DateTime.utc(2026),
    ),
  ];

  test(
    'OpenAI-compatible provider sends the configured model and messages',
    () async {
      final adapter = _RecordingAdapter({
        'choices': [
          {
            'message': {'content': 'A local-first SQLite layer.'},
          },
        ],
      });
      final repository = DioAiCompletionRepository(
        Dio()..httpClientAdapter = adapter,
      );
      final provider = AiProviderConfig(
        id: 'custom',
        name: 'Custom endpoint',
        type: AiProviderType.openAiCompatible,
        baseUrl: Uri.parse('https://example.test/v1'),
        model: 'chosen-model',
      );

      final reply = await repository
          .streamReply(
            provider: provider,
            apiKey: 'test-secret',
            history: history,
          )
          .join();

      expect(reply, 'A local-first SQLite layer.');
      expect(adapter.request!.uri.path, '/v1/chat/completions');
      expect(adapter.request!.headers['Authorization'], 'Bearer test-secret');
      expect(adapter.body['model'], 'chosen-model');
      expect(adapter.body['messages'], hasLength(1));
    },
  );

  test(
    'Gemini uses its native generateContent request and header key',
    () async {
      final adapter = _RecordingAdapter({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Gemini response'},
              ],
            },
          },
        ],
      });
      final repository = DioAiCompletionRepository(
        Dio()..httpClientAdapter = adapter,
      );
      final provider = AiProviderConfig(
        id: 'gemini',
        name: 'Gemini',
        type: AiProviderType.gemini,
        baseUrl: Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/',
        ),
        model: 'gemini-test',
      );

      final reply = await repository
          .streamReply(
            provider: provider,
            apiKey: 'test-secret',
            history: history,
          )
          .join();

      expect(reply, 'Gemini response');
      expect(
        adapter.request!.uri.path,
        '/v1beta/models/gemini-test:generateContent',
      );
      expect(adapter.request!.uri.query, isEmpty);
      expect(adapter.request!.headers['x-goog-api-key'], 'test-secret');
      expect(adapter.body['contents'], hasLength(1));
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._response);
  final Map<String, dynamic> _response;
  RequestOptions? request;
  Map<String, dynamic> body = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final data = options.data;
    body = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : Map<String, dynamic>.from(data as Map);
    return ResponseBody.fromString(
      jsonEncode(_response),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
