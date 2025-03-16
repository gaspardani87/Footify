import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'storage_service.dart';

class ColorBlindModeProvider with ChangeNotifier {
  bool _isColorBlindMode = false;

  ColorBlindModeProvider() {
    _loadColorBlindMode();
  }

  bool get isColorBlindMode => _isColorBlindMode;

  Future<void> _loadColorBlindMode() async {
    try {
      final isEnabled = await StorageService.getBool('footify_color_blind');
      _isColorBlindMode = isEnabled ?? false;
      notifyListeners();
    } catch (e) {
      print('Error loading color blind mode: $e');
    }
  }

  Future<void> toggleColorBlindMode([bool? value]) async {
    _isColorBlindMode = value ?? !_isColorBlindMode;
    try {
      await StorageService.setBool('footify_color_blind', _isColorBlindMode);
    } catch (e) {
      print('Error saving color blind mode: $e');
    }
    notifyListeners();
  }
}