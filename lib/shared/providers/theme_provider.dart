import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_providers.dart';

class ThemeNotifier extends StateNotifier<bool> {
  final Ref _ref;

  ThemeNotifier(this._ref) : super(false) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeService = _ref.read(themeServiceProvider);
    state = await themeService.isDarkMode();
  }

  Future<void> toggleTheme() async {
    final themeService = _ref.read(themeServiceProvider);
    state = !state;
    await themeService.saveThemeMode(state);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  return ThemeNotifier(ref);
});
