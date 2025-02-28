import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  void setLocale(String languageCode) {
    switch (languageCode) {
      case 'English':
        _currentLocale = const Locale('en');
        break;
      case 'Español':
        _currentLocale = const Locale('es');
        break;
      case 'Italiano':  
        _currentLocale = const Locale('it');  
        break;
      case 'Deutsch':
        _currentLocale = const Locale('de');
        break;
      case 'Magyar':
        _currentLocale = const Locale('hu');
        break;
      default:
        _currentLocale = const Locale('en');
    }
    notifyListeners();
  }
}