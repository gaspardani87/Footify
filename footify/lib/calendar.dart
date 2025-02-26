import 'package:flutter/material.dart';
import 'common_layout.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CommonLayout(
      selectedIndex: 1,
      child: Center(
        child: Text(
          'Calendar',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}