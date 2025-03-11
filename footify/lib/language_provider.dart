import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  LanguageProvider() {
    _loadLanguage();
  }

  Locale get currentLocale => _currentLocale;

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    String languageName = prefs.getString('selected_language') ?? 'English';
    setLocale(languageName);
  }

  Future<void> setLocale(String languageName) async {
    String languageCode;
    switch (languageName) {
      case 'English':
        languageCode = 'en';
        break;
      case 'Español':
        languageCode = 'es';
        break;
      case 'Italiano':
        languageCode = 'it';
        break;
      case 'Deutsch':
        languageCode = 'de';
        break;
      case 'Magyar':
        languageCode = 'hu';
        break;
      default:
        languageCode = 'en';
    }
    
    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', languageName);
    notifyListeners();
  }
}