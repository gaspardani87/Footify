import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' if (dart.library.io) 'dart:io' as platform;

class ColorBlindModeProvider with ChangeNotifier {
  bool _isColorBlindMode = false;

  ColorBlindModeProvider() {
    _loadColorBlindMode();
  }

  bool get isColorBlindMode => _isColorBlindMode;

  Future<void> _loadColorBlindMode() async {
    if (kIsWeb) {
      // Use localStorage for web platform
      try {
        final colorBlindStr = platform.window.localStorage['footify_color_blind'];
        _isColorBlindMode = colorBlindStr == 'true';
      } catch (e) {
        print('Error loading color blind mode from localStorage: $e');
        _isColorBlindMode = false; // Default to false on error
      }
    } else {
      // Use SharedPreferences for mobile/desktop platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        _isColorBlindMode = prefs.getBool('is_color_blind') ?? false;
      } catch (e) {
        print('Error loading color blind mode from SharedPreferences: $e');
        _isColorBlindMode = false; // Default to false on error
      }
    }
    notifyListeners();
  }

  Future<void> toggleColorBlindMode(bool value) async {
    _isColorBlindMode = value;
    
    if (kIsWeb) {
      // Use localStorage for web platform
      try {
        platform.window.localStorage['footify_color_blind'] = value.toString();
      } catch (e) {
        print('Error saving color blind mode to localStorage: $e');
      }
    } else {
      // Use SharedPreferences for mobile/desktop platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_color_blind', value);
      } catch (e) {
        print('Error saving color blind mode to SharedPreferences: $e');
      }
    }
    notifyListeners();
  }
}