import 'package:flutter/material.dart';
import 'common_layout.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isDarkMode = true;
  bool notificationsEnabled = false;
  bool isColorBlindMode = false;
  double fontSize = 16.0;
  String selectedLanguage = 'English';

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      selectedIndex: 4,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme Switcher
          ListTile(
            title: const Text('Theme', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Switch between light and dark mode', style: TextStyle(color: Colors.grey)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.wb_sunny, color: Colors.yellow),
                  onPressed: () {
                    setState(() {
                      isDarkMode = false;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.nights_stay, color: Color.fromARGB(255, 68, 88, 99)),
                  onPressed: () {
                    setState(() {
                      isDarkMode = true;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFFFE6AC)),

          // Language Selector
          ListTile(
            title: const Text('Language', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Select your preferred language', style: TextStyle(color: Colors.grey)),
            trailing: DropdownButton<String>(
              value: selectedLanguage,
              dropdownColor: Colors.black,
              items: <String>['English', 'Español', 'Français', 'Deutsch', 'Magyar']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedLanguage = newValue!;
                });
              },
            ),
          ),
          const Divider(color: Color(0xFFFFE6AC)),

          // Notifications Toggle
          ListTile(
            title: const Text('Notifications', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Enable or disable notifications', style: TextStyle(color: Colors.grey)),
            trailing: Switch(
              value: notificationsEnabled,
              onChanged: (bool value) {
                setState(() {
                  notificationsEnabled = value;
                });
              },
              activeColor: Color(0xFFFFE6AC),
              activeTrackColor: Color.fromARGB(255, 87, 87, 87),
              inactiveThumbColor: Color(0xFF1D1D1B),
              inactiveTrackColor: Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          const Divider(color: Color(0xFFFFE6AC)),

          // Accessibility Settings
          ListTile(
            title: const Text('Accessibility', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Adjust accessibility settings', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            title: const Text('Color Blind Mode', style: TextStyle(color: Colors.white)),
            trailing: Switch(
              value: isColorBlindMode,
              onChanged: (bool value) {
                setState(() {
                  isColorBlindMode = value;
                });
              },
              activeColor: Color(0xFFFFE6AC),
              activeTrackColor: Color.fromARGB(255, 87, 87, 87),
              inactiveThumbColor: Color(0xFF1D1D1B),
              inactiveTrackColor: Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          ListTile(
            title: const Text('Font Size', style: TextStyle(color: Colors.white)),
            subtitle: Slider(
              
              value: fontSize,
              min: 10.0,
              max: 30.0,
              divisions: 20,
              activeColor: Color(0xFFFFE6AC),
              inactiveColor: Color.fromARGB(255, 255, 255, 255),
              label: fontSize.round().toString(),
              onChanged: (double value) {
                setState(() {
                  fontSize = value;
                });
              },
            ),
          ),
          const Divider(color: Color(0xFFFFE6AC)),

          // About Us
          ListTile(
            title: const Text('About Us', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Learn more about us', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            title: Row(
              children: [
                IconButton(
                  icon: const Icon(FontAwesomeIcons.instagram, color: Color.fromARGB(255, 255, 255, 255)),
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
                  icon: const Icon(FontAwesomeIcons.twitter, color: Color.fromARGB(255, 255, 255, 255)),
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