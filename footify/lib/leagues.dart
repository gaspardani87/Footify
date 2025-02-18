import 'package:flutter/material.dart';
import 'common_layout.dart';

class LeaguePage extends StatelessWidget {
  const LeaguePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      selectedIndex: 2,
      child: const Center(
        child: Text('League Page', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}