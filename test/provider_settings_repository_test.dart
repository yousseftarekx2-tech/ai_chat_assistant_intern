import 'dart:io';

import 'package:ai_chat_assistant/core/database/app_database.dart';
import 'package:ai_chat_assistant/features/settings/data/secure_provider_settings_repository.dart';
import 'package:ai_chat_assistant/features/settings/domain/entities/ai_provider_config.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  test(
    'provider settings persist while the API key stays in secure storage',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'strix-settings-test-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}settings.sqlite',
      );
      final storage = _MockSecureStorage();
      final secureValues = <String, String>{};
      when(() => storage.read(key: any(named: 'key'))).thenAnswer(
        (invocation) async =>
            secureValues[invocation.namedArguments[#key] as String],
      );
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        secureValues[invocation.namedArguments[#key] as String] =
            invocation.namedArguments[#value] as String;
      });
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        secureValues.remove(invocation.namedArguments[#key] as String);
      });

      final database = AppDatabase(executor: NativeDatabase(file));
      final repository = SecureProviderSettingsRepository(database, storage);
      final provider = AiProviderConfig(
        id: 'custom-1',
        name: 'Private endpoint',
        type: AiProviderType.openAiCompatible,
        baseUrl: Uri.parse('https://example.test/v1'),
        model: 'custom-model',
        apiKey: 'never-store-this-in-sqlite',
      );

      await repository.saveProvider(provider);
      await repository.setActiveProviderId(provider.id);
      await repository.setDarkModeEnabled(true);
      final rawRow =
          (await database
                  .customSelect(
                    'SELECT * FROM providers WHERE id = ?',
                    variables: [Variable.withString('custom-1')],
                  )
                  .get())
              .single
              .data;
      expect(rawRow.containsKey('api_key'), isFalse);
      await database.close();

      final reopened = AppDatabase(executor: NativeDatabase(file));
      final reopenedRepository = SecureProviderSettingsRepository(
        reopened,
        storage,
      );
      final loadedProvider = (await reopenedRepository.getProviders())
          .singleWhere((item) => item.id == 'custom-1');
      expect(loadedProvider.model, 'custom-model');
      expect(loadedProvider.apiKey, 'never-store-this-in-sqlite');
      expect(await reopenedRepository.getActiveProviderId(), 'custom-1');
      expect(await reopenedRepository.getDarkModeEnabled(), isTrue);
      await reopened.close();
      await directory.delete(recursive: true);
    },
  );
}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}
