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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String selectedLanguage = 'English';
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      // Get theme setting
      final isDark = await StorageService.getBool('footify_theme_dark') ?? true;
      
      // Get language setting
      final langStr = await StorageService.getValue('footify_language');
      if (langStr != null) {
        selectedLanguage = langStr;
      }
      
      // Get font size
      final fontSize = await StorageService.getDouble('footify_font_size') ?? 16.0;
      
      // Get color blind mode
      final isColorBlind = await StorageService.getBool('footify_color_blind') ?? false;
      
      // Apply settings via providers
      if (!mounted) return;
      
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final fontSizeProvider = Provider.of<FontSizeProvider>(context, listen: false);
      final colorBlindModeProvider = Provider.of<ColorBlindModeProvider>(context, listen: false);
      
      await themeProvider.toggleTheme(isDark);
      await languageProvider.setLocale(selectedLanguage);
      await fontSizeProvider.setFontSize(fontSize);
      await colorBlindModeProvider.toggleColorBlindMode(isColorBlind);
      
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleTheme(bool isDark) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.toggleTheme(isDark);
  }

  Future<void> _setFontSize(double size) async {
    final fontSizeProvider = Provider.of<FontSizeProvider>(context, listen: false);
    await fontSizeProvider.setFontSize(size);
  }

  Future<void> _toggleColorBlindMode(bool enabled) async {
    final colorBlindModeProvider = Provider.of<ColorBlindModeProvider>(context, listen: false);
    await colorBlindModeProvider.toggleColorBlindMode(enabled);
  }

  Future<void> _changeLanguage(String language) async {
    setState(() {
      selectedLanguage = language;
    });
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    await languageProvider.setLocale(language);
  }

  Future<void> _openURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error opening URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Direct access to current theme state 
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final colorBlindModeProvider = Provider.of<ColorBlindModeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    if (isLoading) {
      return const CommonLayout(
        selectedIndex: 4,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return CommonLayout(
      selectedIndex: 4,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme Switcher
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.theme ?? 'Theme',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.themeText ?? 'Choose light or dark theme',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.wb_sunny, color: !isDarkMode ? Colors.black : Colors.black),
                        label: Text(AppLocalizations.of(context)!.lightMode),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !isDarkMode ? const Color(0xFFFFE6AC) : Colors.grey[300],
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () => _toggleTheme(false),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.nights_stay, color: isDarkMode ? Colors.black : null),
                        label: Text(AppLocalizations.of(context)!.darkMode),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? const Color(0xFFFFE6AC) : Colors.grey[900],
                          foregroundColor: isDarkMode ? Colors.black : Colors.white,
                        ),
                        onPressed: () => _toggleTheme(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Language Selector
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.language ?? 'Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.languageText ?? 'Select your preferred language',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedLanguage,
                        dropdownColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        items: <String>['English', 'Español', 'Italiano', 'Deutsch', 'Magyar']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            _changeLanguage(newValue);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Accessibility Card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.accessibility ?? 'Accessibility',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.accessibilityText ?? 'Adjust accessibility settings',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      AppLocalizations.of(context)?.colorBlindMode ?? 'Color Blind Mode',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    value: colorBlindModeProvider.isColorBlindMode,
                    activeColor: const Color(0xFFFFE6AC),
                    activeTrackColor: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                    onChanged: _toggleColorBlindMode,
                  ),
                  ListTile(
                    title: Text(
                      AppLocalizations.of(context)?.fontSize ?? 'Font Size',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      children: [
                        Slider(
                          value: fontSizeProvider.fontSize,
                          min: 10.0,
                          max: 30.0,
                          divisions: 20,
                          activeColor: const Color(0xFFFFE6AC),
                          inactiveColor: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                          label: fontSizeProvider.fontSize.round().toString(),
                          onChanged: _setFontSize,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLocalizations.of(context)!.small, style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                            TextButton(
                              child: Text(AppLocalizations.of(context)!.reset, style: TextStyle(color: const Color(0xFFFFE6AC))),
                              onPressed: () => _setFontSize(16.0),
                            ),
                            Text(AppLocalizations.of(context)!.large, style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // About Us Card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)?.aboutUs ?? 'About Us',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.aboutUsText ?? 'Follow us on social media',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(FontAwesomeIcons.instagram, 
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 30,
                        ),
                        onPressed: () => _openURL('https://www.instagram.com'),
                      ),
                      const SizedBox(width: 32),
                      IconButton(
                        icon: Icon(FontAwesomeIcons.twitter, 
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 30,
                        ),
                        onPressed: () => _openURL('https://www.x.com'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Settings are saved in your browser and will persist until you clear your browser data.',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}