import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'storage_service.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  LanguageProvider() {
    _loadLanguage();
  }

  Locale get currentLocale => _currentLocale;

  Future<void> _loadLanguage() async {
    try {
      final langStr = await StorageService.getValue('footify_language');
      if (langStr != null) {
        await setLocale(langStr);
      }
    } catch (e) {
      print('Error loading language: $e');
    }
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
    
    try {
      await StorageService.setValue('footify_language', languageName);
    } catch (e) {
      print('Error saving language: $e');
    }
    
    notifyListeners();
  }
}