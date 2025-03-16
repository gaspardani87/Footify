import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'storage_service.dart';

class FontSizeProvider with ChangeNotifier {
  double _fontSize = 16.0;

  FontSizeProvider() {
    _loadFontSize();
  }

  double get fontSize => _fontSize;

  Future<void> _loadFontSize() async {
    try {
      final size = await StorageService.getDouble('footify_font_size');
      _fontSize = size ?? 16.0;
      notifyListeners();
    } catch (e) {
      print('Error loading font size: $e');
    }
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    try {
      await StorageService.setDouble('footify_font_size', size);
    } catch (e) {
      print('Error saving font size: $e');
    }
    notifyListeners();
  }
}