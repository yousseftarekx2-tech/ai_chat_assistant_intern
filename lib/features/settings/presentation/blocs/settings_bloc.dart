import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/ai_provider_config.dart';
import '../../domain/repositories/provider_settings_repository.dart';

sealed class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

final class SettingsRequested extends SettingsEvent {
  const SettingsRequested();
}

final class ProviderSaved extends SettingsEvent {
  const ProviderSaved(this.provider);
  final AiProviderConfig provider;
  @override
  List<Object?> get props => [provider];
}

final class ProviderRemoved extends SettingsEvent {
  const ProviderRemoved(this.providerId);
  final String providerId;
  @override
  List<Object?> get props => [providerId];
}

final class ActiveProviderChanged extends SettingsEvent {
  const ActiveProviderChanged(this.providerId);
  final String providerId;
  @override
  List<Object?> get props => [providerId];
}

final class DarkModeChanged extends SettingsEvent {
  const DarkModeChanged(this.enabled);
  final bool enabled;
  @override
  List<Object?> get props => [enabled];
}

class SettingsState extends Equatable {
  const SettingsState({
    this.isLoading = false,
    this.providers = const [],
    this.activeProviderId,
    this.darkModeEnabled = false,
    this.error,
  });

  final bool isLoading;
  final List<AiProviderConfig> providers;
  final String? activeProviderId;
  final bool darkModeEnabled;
  final String? error;

  AiProviderConfig? get activeProvider {
    for (final provider in providers) {
      if (provider.id == activeProviderId) return provider;
    }
    return null;
  }

  SettingsState copyWith({
    bool? isLoading,
    List<AiProviderConfig>? providers,
    String? activeProviderId,
    bool? darkModeEnabled,
    String? error,
    bool clearError = false,
  }) => SettingsState(
    isLoading: isLoading ?? this.isLoading,
    providers: providers ?? this.providers,
    activeProviderId: activeProviderId ?? this.activeProviderId,
    darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [
    isLoading,
    providers,
    activeProviderId,
    darkModeEnabled,
    error,
  ];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._repository) : super(const SettingsState(isLoading: true)) {
    on<SettingsRequested>(_load, transformer: sequential());
    on<ProviderSaved>(_saveProvider, transformer: sequential());
    on<ProviderRemoved>(_removeProvider, transformer: sequential());
    on<ActiveProviderChanged>(_setActiveProvider, transformer: sequential());
    on<DarkModeChanged>(_setDarkMode, transformer: sequential());
  }

  final ProviderSettingsRepository _repository;

  Future<void> _load(
    SettingsRequested event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final providers = await _repository.getProviders();
      var activeId = await _repository.getActiveProviderId();
      if (!providers.any((provider) => provider.id == activeId)) {
        activeId = providers
            .where((provider) => provider.isEnabled)
            .firstOrNull
            ?.id;
        if (activeId != null) await _repository.setActiveProviderId(activeId);
      }
      emit(
        SettingsState(
          providers: providers,
          activeProviderId: activeId,
          darkModeEnabled: await _repository.getDarkModeEnabled(),
        ),
      );
    } on Exception catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Could not load settings: $error',
        ),
      );
    }
  }

  Future<void> _saveProvider(
    ProviderSaved event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _repository.saveProvider(event.provider);
      final providers = await _repository.getProviders();
      final activeId = state.activeProviderId ?? event.provider.id;
      await _repository.setActiveProviderId(activeId);
      emit(
        state.copyWith(
          providers: providers,
          activeProviderId: activeId,
          clearError: true,
        ),
      );
    } on Exception catch (error) {
      emit(state.copyWith(error: 'Could not save provider: $error'));
    }
  }

  Future<void> _removeProvider(
    ProviderRemoved event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _repository.deleteProvider(event.providerId);
      final providers = await _repository.getProviders();
      final activeId = state.activeProviderId == event.providerId
          ? providers.where((item) => item.isEnabled).firstOrNull?.id
          : state.activeProviderId;
      if (activeId != null) await _repository.setActiveProviderId(activeId);
      emit(
        state.copyWith(
          providers: providers,
          activeProviderId: activeId,
          clearError: true,
        ),
      );
    } on Exception catch (error) {
      emit(state.copyWith(error: 'Could not remove provider: $error'));
    }
  }

  Future<void> _setActiveProvider(
    ActiveProviderChanged event,
    Emitter<SettingsState> emit,
  ) async {
    if (!state.providers.any(
      (item) => item.id == event.providerId && item.isEnabled,
    )) {
      emit(state.copyWith(error: 'Choose an enabled provider.'));
      return;
    }
    try {
      await _repository.setActiveProviderId(event.providerId);
      emit(
        state.copyWith(activeProviderId: event.providerId, clearError: true),
      );
    } on Exception catch (error) {
      emit(state.copyWith(error: 'Could not select provider: $error'));
    }
  }

  Future<void> _setDarkMode(
    DarkModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _repository.setDarkModeEnabled(event.enabled);
      emit(state.copyWith(darkModeEnabled: event.enabled, clearError: true));
    } on Exception catch (error) {
      emit(state.copyWith(error: 'Could not save appearance setting: $error'));
    }
  }
}
