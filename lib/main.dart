import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection_container.dart';
import 'features/chat/presentation/blocs/chat_bloc.dart';
import 'features/chat/presentation/blocs/conversation_bloc.dart';
import 'features/chat/presentation/screens/conversation_list_screen.dart';
import 'features/settings/presentation/blocs/settings_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const StrixChatApp());
}

class StrixChatApp extends StatelessWidget {
  const StrixChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<SettingsBloc>()..add(const SettingsRequested()),
        ),
        BlocProvider(create: (_) => getIt<ConversationBloc>()),
        BlocProvider(create: (_) => getIt<ChatBloc>()),
      ],
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settings) => MaterialApp(
          title: 'Strix AI',
          debugShowCheckedModeBanner: false,
          themeMode: settings.darkModeEnabled
              ? ThemeMode.dark
              : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6050C8),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFFAF9FF),
            appBarTheme: const AppBarTheme(centerTitle: false),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFB9AEFF),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(centerTitle: false),
          ),
          home: const ConversationListScreen(),
        ),
      ),
    );
  }
}
