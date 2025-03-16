import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' if (dart.library.io) 'dart:io' as platform;

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadTheme() async {
    if (kIsWeb) {
      // Use localStorage for web platform
      try {
        final themeStr = platform.window.localStorage['footify_theme'];
        final isDarkMode = themeStr == 'dark' || themeStr == null; // Default to dark
        _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      } catch (e) {
        print('Error loading theme from localStorage: $e');
        _themeMode = ThemeMode.dark; // Default to dark on error
      }
    } else {
      // Use SharedPreferences for mobile/desktop platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        final isDarkMode = prefs.getBool('is_dark_mode') ?? true;
        _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      } catch (e) {
        print('Error loading theme from SharedPreferences: $e');
        _themeMode = ThemeMode.dark; // Default to dark on error
      }
    }
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    
    if (kIsWeb) {
      // Use localStorage for web platform
      try {
        platform.window.localStorage['footify_theme'] = isDarkMode ? 'dark' : 'light';
      } catch (e) {
        print('Error saving theme to localStorage: $e');
      }
    } else {
      // Use SharedPreferences for mobile/desktop platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_dark_mode', isDarkMode);
      } catch (e) {
        print('Error saving theme to SharedPreferences: $e');
      }
    }
    notifyListeners();
  }
}