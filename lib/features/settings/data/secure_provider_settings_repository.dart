import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/database/app_database.dart';
import '../../../core/error/app_exception.dart';
import '../domain/entities/ai_provider_config.dart';
import '../domain/repositories/provider_settings_repository.dart';
import 'default_providers.dart';

class SecureProviderSettingsRepository implements ProviderSettingsRepository {
  const SecureProviderSettingsRepository(this._database, this._storage);

  final AppDatabase _database;
  final FlutterSecureStorage _storage;

  @override
  Future<List<AiProviderConfig>> getProviders() async {
    final rows = await _database.customSelect('SELECT * FROM providers').get();
    if (rows.isEmpty) {
      final initialized = await _database
          .customSelect(
            "SELECT value FROM preferences WHERE key = 'providers_initialized'",
          )
          .get();
      if (initialized.isNotEmpty) return const [];
      for (final provider in defaultProviders) {
        await saveProvider(provider);
      }
      await _database.customStatement(
        "INSERT INTO preferences(key,value) VALUES('providers_initialized','true')",
      );
      return getProviders();
    }
    return Future.wait(
      rows.map((row) async {
        final data = row.data;
        final id = data['id']! as String;
        final config = AiProviderConfig(
          id: id,
          name: data['name']! as String,
          type: AiProviderType.values.byName(data['type']! as String),
          baseUrl: Uri.parse(data['base_url']! as String),
          model: data['model']! as String,
          isEnabled: data['enabled']! as int == 1,
          apiKey: await getApiKey(id) ?? '',
        );
        return config;
      }),
    );
  }

  @override
  Future<void> saveProvider(AiProviderConfig provider) async {
    try {
      await _database.customStatement(
        '''INSERT INTO providers(id,name,type,base_url,model,enabled)
        VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET
        name=excluded.name, type=excluded.type, base_url=excluded.base_url,
        model=excluded.model, enabled=excluded.enabled''',
        [
          provider.id,
          provider.name,
          provider.type.name,
          provider.baseUrl.toString(),
          provider.model,
          provider.isEnabled ? 1 : 0,
        ],
      );
      if (provider.apiKey.isNotEmpty) {
        await saveApiKey(provider.id, provider.apiKey);
      }
    } on Exception catch (error) {
      throw StorageException('Could not save provider settings: $error');
    }
  }

  @override
  Future<void> deleteProvider(String providerId) async {
    await _database.customStatement('DELETE FROM providers WHERE id = ?', [
      providerId,
    ]);
    await _storage.delete(key: _key(providerId));
    if (await getActiveProviderId() == providerId) {
      await _database.customStatement(
        "DELETE FROM preferences WHERE key = 'active_provider_id'",
      );
    }
  }

  @override
  Future<String?> getApiKey(String providerId) =>
      _storage.read(key: _key(providerId));

  @override
  Future<void> saveApiKey(String providerId, String apiKey) =>
      _storage.write(key: _key(providerId), value: apiKey);

  @override
  Future<String?> getActiveProviderId() async {
    final rows = await _database
        .customSelect(
          "SELECT value FROM preferences WHERE key = 'active_provider_id'",
        )
        .get();
    return rows.isEmpty ? null : rows.first.data['value']! as String;
  }

  @override
  Future<void> setActiveProviderId(String providerId) async {
    await _database.customStatement(
      '''INSERT INTO preferences(key,value) VALUES('active_provider_id',?)
      ON CONFLICT(key) DO UPDATE SET value=excluded.value''',
      [providerId],
    );
  }

  @override
  Future<bool> getDarkModeEnabled() async {
    final rows = await _database
        .customSelect("SELECT value FROM preferences WHERE key = 'dark_mode'")
        .get();
    return rows.isNotEmpty && rows.first.data['value'] == 'true';
  }

  @override
  Future<void> setDarkModeEnabled(bool enabled) => _database.customStatement(
    '''INSERT INTO preferences(key,value) VALUES('dark_mode',?)
    ON CONFLICT(key) DO UPDATE SET value=excluded.value''',
    [enabled.toString()],
  );

  String _key(String providerId) => 'ai_api_key_$providerId';
}
