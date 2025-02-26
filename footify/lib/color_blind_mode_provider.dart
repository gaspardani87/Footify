import 'package:flutter/material.dart';

class ColorBlindModeProvider with ChangeNotifier {
  bool _isColorBlindMode = false;

  bool get isColorBlindMode => _isColorBlindMode;

  void toggleColorBlindMode(bool value) {
    _isColorBlindMode = value;
    notifyListeners();
  }
}