import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ThemeService {
  static const _fileName = 'theme_settings.json';

  Future<bool> isDarkMode() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return false;
      final contents = await file.readAsString();
      final data = jsonDecode(contents) as Map<String, dynamic>;
      return data['isDarkMode'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveThemeMode(bool isDark) async {
    try {
      final file = await _getFile();
      final data = {'isDarkMode': isDark};
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }
}
