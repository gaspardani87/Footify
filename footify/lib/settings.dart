import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'font_size_provider.dart';
import 'color_blind_mode_provider.dart';
import 'common_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = false;
  String selectedLanguage = 'English';

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
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
            title: Text('Theme', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text('Switch between light and dark mode', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
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
            title: Text('Language', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text('Select your preferred language', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
            trailing: DropdownButton<String>(
              value: selectedLanguage,
              dropdownColor: isDarkMode ? Colors.grey[850] : Colors.white,
              items: <String>['English', 'Español', 'Français', 'Deutsch', 'Magyar']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedLanguage = newValue!;
                });
              },
            ),
          ),
          Divider(color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black),

          // Notifications Toggle
          ListTile(
            title: Text('Notifications', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text('Enable or disable notifications', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
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
            title: Text('Accessibility', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text('Adjust accessibility settings', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
          ),
          ListTile(
            title: Text('Color Blind Mode', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
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
            title: Text('Font Size', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
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
            title: Text('About Us', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            subtitle: Text('Learn more about us', style: TextStyle(color: isDarkMode ? Colors.grey : Colors.black54)),
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