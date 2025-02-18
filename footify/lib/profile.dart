import 'package:flutter/material.dart';
import 'common_layout.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      selectedIndex: 3,
      child: const Center(
        child: Text('Profile Page', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}