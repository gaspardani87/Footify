import 'package:flutter/material.dart';
import 'storage_service.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isChanging = false;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isChanging => _isChanging;

  Future<void> _loadTheme() async {
    try {
      final isDarkMode = await StorageService.getBool('footify_theme_dark') ?? true;
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (e) {
      print('Error loading theme: $e');
      _themeMode = ThemeMode.dark; // Default to dark on error
    }
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    _isChanging = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 50));
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    
    try {
      await StorageService.setBool('footify_theme_dark', isDarkMode);
    } catch (e) {
      print('Error saving theme: $e');
    }

    _isChanging = false;
    notifyListeners();
  }
}