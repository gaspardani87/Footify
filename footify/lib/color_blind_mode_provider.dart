import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ColorBlindModeProvider with ChangeNotifier {
  bool _isColorBlindMode = false;

  ColorBlindModeProvider() {
    _loadColorBlindMode();
  }

  bool get isColorBlindMode => _isColorBlindMode;

  Future<void> _loadColorBlindMode() async {
    final prefs = await SharedPreferences.getInstance();
    _isColorBlindMode = prefs.getBool('is_color_blind') ?? false;
    notifyListeners();
  }

  Future<void> toggleColorBlindMode(bool value) async {
    _isColorBlindMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_color_blind', value);
    notifyListeners();
  }
}