import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    // Initialize selectedLanguage based on current locale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final currentLocale = languageProvider.currentLocale.languageCode;
      setState(() {
        selectedLanguage = _getLanguageName(currentLocale);
      });
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

  void _updateLanguage(String newLanguage) {
    setState(() {
      selectedLanguage = newLanguage;
    });
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
                  onPressed: () {
                    themeProvider.toggleTheme(false); // Set to light mode
                  },
                ),
                IconButton(
                  icon: Icon(Icons.nights_stay, color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black),
                  onPressed: () {
                    themeProvider.toggleTheme(true); // Set to dark mode
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
              onChanged: (bool value) {
                setState(() {
                  notificationsEnabled = value;
                });
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
              onChanged: (bool value) {
                colorBlindModeProvider.toggleColorBlindMode(value);
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
            subtitle: Slider(
              value: fontSizeProvider.fontSize,
              min: 10.0,
              max: 30.0,
              divisions: 20,
              activeColor: const Color(0xFFFFE6AC),
              inactiveColor: isDarkMode ? Colors.grey : Colors.grey[400],
              label: fontSizeProvider.fontSize.round().toString(),
              onChanged: (double value) {
                fontSizeProvider.setFontSize(value);
              },
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