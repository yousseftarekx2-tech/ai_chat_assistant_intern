import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../database/app_database.dart';
import '../../features/chat/data/dio_ai_completion_repository.dart';
import '../../features/chat/data/drift_chat_repository.dart';
import '../../features/chat/domain/repositories/ai_completion_repository.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/send_chat_message.dart';
import '../../features/chat/presentation/blocs/chat_bloc.dart';
import '../../features/chat/presentation/blocs/conversation_bloc.dart';
import '../../features/settings/data/secure_provider_settings_repository.dart';
import '../../features/settings/domain/repositories/provider_settings_repository.dart';
import '../../features/settings/presentation/blocs/settings_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (getIt.isRegistered<AppDatabase>()) return;
  getIt.registerLazySingleton<AppDatabase>(AppDatabase.new);
  getIt.registerLazySingleton<Dio>(
    () => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 20),
      ),
    ),
  );
  getIt.registerLazySingleton<FlutterSecureStorage>(FlutterSecureStorage.new);
  getIt.registerLazySingleton<ChatRepository>(
    () => DriftChatRepository(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<AiCompletionRepository>(
    () => DioAiCompletionRepository(getIt<Dio>()),
  );
  getIt.registerFactory(() => SendChatMessage(getIt<AiCompletionRepository>()));
  getIt.registerLazySingleton<ProviderSettingsRepository>(
    () => SecureProviderSettingsRepository(
      getIt<AppDatabase>(),
      getIt<FlutterSecureStorage>(),
    ),
  );
  getIt.registerFactory(() => ConversationBloc(getIt<ChatRepository>()));
  getIt.registerFactory(
    () => ChatBloc(getIt<ChatRepository>(), getIt<SendChatMessage>()),
  );
  getIt.registerFactory(
    () => SettingsBloc(getIt<ProviderSettingsRepository>()),
  );
}
