enum AiProviderType { openAi, gemini, openAiCompatible, groq, anthropic }

class AiProviderConfig {
  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.model,
    this.isEnabled = true,
    this.apiKey = '',
  });

  final String id;
  final String name;
  final AiProviderType type;
  final Uri baseUrl;
  final String model;
  final bool isEnabled;
  final String apiKey;

  AiProviderConfig copyWith({
    String? name,
    AiProviderType? type,
    Uri? baseUrl,
    String? model,
    bool? isEnabled,
    String? apiKey,
  }) => AiProviderConfig(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    isEnabled: isEnabled ?? this.isEnabled,
    apiKey: apiKey ?? this.apiKey,
  );
}
