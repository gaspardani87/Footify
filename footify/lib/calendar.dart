import 'package:flutter/material.dart';
import 'common_layout.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      selectedIndex: 1,
      child: const Center(
        child: Text('Calendar', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}