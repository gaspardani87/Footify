import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'font_size_provider.dart';
import 'color_blind_mode_provider.dart';
import 'common_layout.dart';
import 'language_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = false;
  late String selectedLanguage;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      selectedLanguage = prefs.getString('selected_language') ?? 'English';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final fontSizeProvider = Provider.of<FontSizeProvider>(context, listen: false);
      final colorBlindModeProvider = Provider.of<ColorBlindModeProvider>(context, listen: false);

      // Load saved settings
      bool isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      double fontSize = prefs.getDouble('font_size') ?? 16.0;
      bool isColorBlind = prefs.getBool('is_color_blind') ?? false;

      // Apply saved settings
      themeProvider.toggleTheme(isDarkMode);
      fontSizeProvider.setFontSize(fontSize);
      colorBlindModeProvider.toggleColorBlindMode(isColorBlind);
      languageProvider.setLocale(selectedLanguage);
    });
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'it':  
        return 'Italiano';  
      case 'de':
        return 'Deutsch';
      case 'hu':
        return 'Magyar';
      default:
        return 'English';
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  void _updateLanguage(String newLanguage) async {
    setState(() {
      selectedLanguage = newLanguage;
    });
    await prefs.setString('selected_language', newLanguage);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.setLocale(newLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final colorBlindModeProvider = Provider.of<ColorBlindModeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CommonLayout(
      selectedIndex: 4,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme Switcher
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.theme,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.themeText,
              style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.wb_sunny, color: isDarkMode ? Colors.grey : const Color(0xFFFFE6AC)),
                  onPressed: () async {
                    themeProvider.toggleTheme(false);
                    await prefs.setBool('is_dark_mode', false);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.nights_stay, color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black),
                  onPressed: () async {
                    themeProvider.toggleTheme(true);
                    await prefs.setBool('is_dark_mode', true);
                  },
                ),
              ],
            ),
          ),
          Divider(color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black),

          // Language Selector
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.language,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.languageText,
              style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)
            ),
            trailing: DropdownButton<String>(
              value: selectedLanguage,
              dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
              items: <String>['English', 'Español', 'Italiano', 'Deutsch', 'Magyar']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _updateLanguage(newValue);
                }
              },
            ),
          ),
          Divider(color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black),

          // Notifications Toggle
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.notifications, 
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text(
              AppLocalizations.of(context)!.notificationsText,
              style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: (bool value) async {
                setState(() {
                  notificationsEnabled = value;
                });
                await prefs.setBool('notifications_enabled', value);
              },
              activeColor: const Color(0xFFFFE6AC),
              activeTrackColor: isDarkMode ? Colors.grey : Colors.grey[400],
              inactiveThumbColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              inactiveTrackColor: isDarkMode ? Colors.grey[600] : Colors.grey[200],
            ),
          ),
          Divider(color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black),

          // Accessibility Settings
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.accessibility, 
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text(
              AppLocalizations.of(context)!.accessibilityText, 
              style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
          ),
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.colorBlindMode,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)
            ),
            trailing: Switch(
              value: colorBlindModeProvider.isColorBlindMode,
              onChanged: (bool value) async {
                colorBlindModeProvider.toggleColorBlindMode(value);
                await prefs.setBool('is_color_blind', value);
              },
              activeColor: const Color(0xFFFFE6AC),
              activeTrackColor: isDarkMode ? Colors.grey : Colors.grey[400],
              inactiveThumbColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              inactiveTrackColor: isDarkMode ? Colors.grey[600] : Colors.grey[200],
            ),
          ),
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.fontSize,
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: fontSizeProvider.fontSize,
                    min: 10.0,
                    max: 30.0,
                    divisions: 20,
                    activeColor: const Color(0xFFFFE6AC),
                    inactiveColor: isDarkMode ? Colors.grey : Colors.grey[400],
                    label: fontSizeProvider.fontSize.round().toString(),
                    onChanged: (double value) async {
                      fontSizeProvider.setFontSize(value);
                      await prefs.setDouble('font_size', value);
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white : Colors.black),
                  onPressed: () async {
                    fontSizeProvider.setFontSize(16.0);
                    await prefs.setDouble('font_size', 16.0);
                  },
                ),
              ],
            ),
          ),
          Divider(color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black),

          // About Us
          ListTile(
            title: Text(
              AppLocalizations.of(context)!.aboutUs, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text(
              AppLocalizations.of(context)!.aboutUsText, 
              style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
          ),
          ListTile(
            title: Row(
              children: [
                IconButton(
                  icon: Icon(FontAwesomeIcons.instagram, color: isDarkMode ? Colors.white : Colors.black),
                  onPressed: () async {
                    final Uri url = Uri.parse('https://www.instagram.com');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      throw 'Could not launch $url';
                    }
                  },
                ),
                IconButton(
                  icon: Icon(FontAwesomeIcons.twitter, color: isDarkMode ? Colors.white : Colors.black),
                  onPressed: () async {
                    final Uri url = Uri.parse('https://www.x.com');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      throw 'Could not launch $url';
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}