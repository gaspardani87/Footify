import 'package:flutter/material.dart';
import 'common_layout.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      selectedIndex: 4,
      child: const Center(
        child: Text('Settings Page', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}