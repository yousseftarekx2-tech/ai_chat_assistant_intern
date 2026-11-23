import 'package:dio/dio.dart';

import '../../../core/error/app_exception.dart';
import '../../settings/domain/entities/ai_provider_config.dart';
import '../domain/entities/chat_message.dart';
import '../domain/repositories/ai_completion_repository.dart';

class DioAiCompletionRepository implements AiCompletionRepository {
  DioAiCompletionRepository(this._dio);

  final Dio _dio;

  @override
  Stream<String> streamReply({
    required AiProviderConfig provider,
    required String apiKey,
    required List<ChatMessage> history,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const ConfigurationException('Add an API key for this provider.');
    }
    if (!provider.isEnabled) {
      throw ConfigurationException('${provider.name} is disabled.');
    }

    try {
      final messages = history
          .where((message) => message.role != MessageRole.system)
          .map(
            (message) => {
              'role': message.role == MessageRole.assistant
                  ? 'assistant'
                  : 'user',
              'content': message.content,
            },
          )
          .toList();

      final content = switch (provider.type) {
        AiProviderType.openAi ||
        AiProviderType.openAiCompatible ||
        AiProviderType.groq => await _requestOpenAi(provider, apiKey, messages),
        AiProviderType.gemini => await _requestGemini(
          provider,
          apiKey,
          history,
        ),
        AiProviderType.anthropic => await _requestAnthropic(
          provider,
          apiKey,
          messages,
        ),
      };

      if (content == null || content.trim().isEmpty) {
        throw const NetworkException(
          'The AI provider returned an empty reply.',
        );
      }
      yield content;
    } on DioException catch (error) {
      throw _networkError(provider, error);
    }
  }

  Future<String?> _requestOpenAi(
    AiProviderConfig provider,
    String apiKey,
    List<Map<String, String>> messages,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint(provider.baseUrl, 'chat/completions'),
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: {'model': provider.model, 'messages': messages},
    );
    final choices = response.data?['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map<String, dynamic>) return null;
    final message = first['message'];
    return message is Map<String, dynamic>
        ? message['content'] as String?
        : null;
  }

  Future<String?> _requestGemini(
    AiProviderConfig provider,
    String apiKey,
    List<ChatMessage> history,
  ) async {
    final contents = history
        .where((message) => message.role != MessageRole.system)
        .map(
          (message) => {
            'role': message.role == MessageRole.assistant ? 'model' : 'user',
            'parts': [
              {'text': message.content},
            ],
          },
        )
        .toList();
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint(provider.baseUrl, '${provider.model}:generateContent'),
      options: Options(headers: {'x-goog-api-key': apiKey}),
      data: {'contents': contents},
    );
    final candidates = response.data?['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map<String, dynamic>) return null;
    final content = first['content'];
    if (content is! Map<String, dynamic>) return null;
    final parts = content['parts'];
    if (parts is! List) return null;
    return parts
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'] as String? ?? '')
        .join();
  }

  Future<String?> _requestAnthropic(
    AiProviderConfig provider,
    String apiKey,
    List<Map<String, String>> messages,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _endpoint(provider.baseUrl, 'messages'),
      options: Options(
        headers: {'x-api-key': apiKey, 'anthropic-version': '2023-06-01'},
      ),
      data: {'model': provider.model, 'max_tokens': 2048, 'messages': messages},
    );
    final content = response.data?['content'];
    if (content is! List) return null;
    return content
        .whereType<Map<String, dynamic>>()
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String? ?? '')
        .join();
  }

  String _endpoint(Uri baseUrl, String path) {
    final basePath = baseUrl.path.endsWith('/')
        ? baseUrl.path
        : '${baseUrl.path}/';
    return baseUrl.replace(path: '$basePath$path').toString();
  }

  AppException _networkError(AiProviderConfig provider, DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return NetworkException('The API key for ${provider.name} was rejected.');
    }
    if (status == 429) {
      return NetworkException(
        '${provider.name} is rate limiting requests. Try again shortly.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return NetworkException(
        '${provider.name} timed out. Check your connection and retry.',
      );
    }
    if (status != null) {
      return NetworkException(
        '${provider.name} returned an error (HTTP $status).',
      );
    }
    return NetworkException(
      'Could not reach ${provider.name}. Check your connection.',
    );
  }
}
