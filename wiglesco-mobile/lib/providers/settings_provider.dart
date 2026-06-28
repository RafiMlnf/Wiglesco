import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final bool useServerMode;
  final String serverUrl;

  const SettingsState({
    this.useServerMode = false,
    this.serverUrl = 'http://10.0.2.2:8000',
  });

  SettingsState copyWith({
    bool? useServerMode,
    String? serverUrl,
  }) {
    return SettingsState(
      useServerMode: useServerMode ?? this.useServerMode,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setServerMode(bool active) {
    state = state.copyWith(useServerMode: active);
  }

  void setServerUrl(String url) {
    state = state.copyWith(serverUrl: url);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
