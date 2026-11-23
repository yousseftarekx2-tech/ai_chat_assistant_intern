import 'package:ai_chat_assistant/features/settings/data/default_providers.dart';
import 'package:ai_chat_assistant/features/settings/domain/entities/ai_provider_config.dart';
import 'package:ai_chat_assistant/features/settings/domain/repositories/provider_settings_repository.dart';
import 'package:ai_chat_assistant/features/settings/presentation/blocs/settings_bloc.dart';
import 'package:ai_chat_assistant/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings loads providers and saves the dark mode preference', (
    tester,
  ) async {
    final repository = _MemorySettingsRepository();
    final bloc = SettingsBloc(repository)..add(const SettingsRequested());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: bloc, child: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI providers'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('Google Gemini'), findsOneWidget);
    expect(find.text('OpenAI-compatible endpoint'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(repository.darkMode, isTrue);
    expect(bloc.state.darkModeEnabled, isTrue);
  });
}

class _MemorySettingsRepository implements ProviderSettingsRepository {
  List<AiProviderConfig> providers = [...defaultProviders];
  String? activeId = 'openai';
  bool darkMode = false;

  @override
  Future<void> deleteProvider(String providerId) async {
    providers.removeWhere((provider) => provider.id == providerId);
  }

  @override
  Future<String?> getActiveProviderId() async => activeId;

  @override
  Future<String?> getApiKey(String providerId) async => null;

  @override
  Future<bool> getDarkModeEnabled() async => darkMode;

  @override
  Future<List<AiProviderConfig>> getProviders() async => providers;

  @override
  Future<void> saveApiKey(String providerId, String apiKey) async {}

  @override
  Future<void> saveProvider(AiProviderConfig provider) async {
    providers = [
      ...providers.where((item) => item.id != provider.id),
      provider,
    ];
  }

  @override
  Future<void> setActiveProviderId(String providerId) async {
    activeId = providerId;
  }

  @override
  Future<void> setDarkModeEnabled(bool enabled) async {
    darkMode = enabled;
  }
}
