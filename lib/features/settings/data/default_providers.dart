import '../domain/entities/ai_provider_config.dart';

final defaultProviders = <AiProviderConfig>[
  AiProviderConfig(
    id: 'openai',
    name: 'OpenAI',
    type: AiProviderType.openAi,
    baseUrl: Uri(scheme: 'https', host: 'api.openai.com', path: '/v1'),
    model: 'gpt-4o-mini',
  ),
  AiProviderConfig(
    id: 'gemini',
    name: 'Google Gemini',
    type: AiProviderType.gemini,
    baseUrl: Uri(
      scheme: 'https',
      host: 'generativelanguage.googleapis.com',
      path: '/v1beta/models/',
    ),
    model: 'gemini-3.8-flash',
  ),
  AiProviderConfig(
    id: 'openai-compatible',
    name: 'OpenAI-compatible endpoint',
    type: AiProviderType.openAiCompatible,
    baseUrl: Uri(scheme: 'https', host: 'openrouter.ai', path: '/api/v1/'),
    model: 'openai/gpt-4o-mini',
  ),
  AiProviderConfig(
    id: 'groq',
    name: 'Groq',
    type: AiProviderType.groq,
    baseUrl: Uri(scheme: 'https', host: 'api.groq.com', path: '/openai/v1'),
    model: 'openai/gpt-oss-120b',
  ),
  AiProviderConfig(
    id: 'anthropic',
    name: 'Anthropic',
    type: AiProviderType.anthropic,
    baseUrl: Uri(scheme: 'https', host: 'api.anthropic.com', path: '/v1'),
    model: 'claude-3-5-haiku-latest',
  ),
];
