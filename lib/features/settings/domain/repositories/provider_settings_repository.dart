import '../entities/ai_provider_config.dart';

abstract interface class ProviderSettingsRepository {
  Future<List<AiProviderConfig>> getProviders();
  Future<void> saveProvider(AiProviderConfig provider);
  Future<void> deleteProvider(String providerId);
  Future<String?> getActiveProviderId();
  Future<void> setActiveProviderId(String providerId);
  Future<bool> getDarkModeEnabled();
  Future<void> setDarkModeEnabled(bool enabled);
  Future<String?> getApiKey(String providerId);
  Future<void> saveApiKey(String providerId, String apiKey);
}
