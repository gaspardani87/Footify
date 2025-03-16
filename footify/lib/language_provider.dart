import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' if (dart.library.io) 'dart:io' as platform;

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  LanguageProvider() {
    _loadLanguage();
  }

  Locale get currentLocale => _currentLocale;

  Future<void> _loadLanguage() async {
    String languageName = 'English'; // Default
    
    if (kIsWeb) {
      // Use localStorage for web platform
      try {
        final langStr = platform.window.localStorage['footify_language'];
        if (langStr != null) {
          languageName = langStr;
        }
      } catch (e) {
        print('Error loading language from localStorage: $e');
        // Fallback to default English
      }
    } else {
      // Use SharedPreferences for mobile/desktop platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        languageName = prefs.getString('selected_language') ?? 'English';
      } catch (e) {
        print('Error loading language from SharedPreferences: $e');
        // Fallback to default English
      }
    }
    
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
    
    if (kIsWeb) {
      // Use localStorage for web platform
      try {
        platform.window.localStorage['footify_language'] = languageName;
      } catch (e) {
        print('Error saving language to localStorage: $e');
      }
    } else {
      // Use SharedPreferences for mobile/desktop platforms
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_language', languageName);
      } catch (e) {
        print('Error saving language to SharedPreferences: $e');
      }
    }
    
    notifyListeners();
  }
}