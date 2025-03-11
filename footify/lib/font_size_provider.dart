import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeProvider with ChangeNotifier {
  double _fontSize = 16.0;

  FontSizeProvider() {
    _loadFontSize();
  }

  double get fontSize => _fontSize;

  Future<void> _loadFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('font_size') ?? 16.0;
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
    notifyListeners();
  }
}