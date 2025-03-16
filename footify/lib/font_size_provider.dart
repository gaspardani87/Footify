import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' if (dart.library.io) 'dart:io' as platform;

class FontSizeProvider with ChangeNotifier {
  double _fontSize = 16.0;

  FontSizeProvider() {
    _loadFontSize();
  }

  double get fontSize => _fontSize;

  Future<void> _loadFontSize() async {
    if (kIsWeb) {
      // Use localStorage for web platform
      try {
        final fontSizeStr = platform.window.localStorage['footify_font_size'];
        _fontSize = fontSizeStr != null ? double.tryParse(fontSizeStr) ?? 16.0 : 16.0;
      } catch (e) {
        print('Error loading font size from localStorage: $e');
        _fontSize = 16.0; // Default font size on error
      }
    } else {
      // Use SharedPreferences for mobile/desktop platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        _fontSize = prefs.getDouble('font_size') ?? 16.0;
      } catch (e) {
        print('Error loading font size from SharedPreferences: $e');
        _fontSize = 16.0; // Default font size on error
      }
    }
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    
    if (kIsWeb) {
      // Use localStorage for web platform
      try {
        platform.window.localStorage['footify_font_size'] = size.toString();
      } catch (e) {
        print('Error saving font size to localStorage: $e');
      }
    } else {
      // Use SharedPreferences for mobile/desktop platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('font_size', size);
      } catch (e) {
        print('Error saving font size to SharedPreferences: $e');
      }
    }
    notifyListeners();
  }
}