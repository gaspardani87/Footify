import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'common_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _matchDays = {};

  @override
  void initState() {
    super.initState();
    _loadMatchDays();
  }

  Future<void> _loadMatchDays() async {
    // Here you would typically load the match dates for the user's favorite team
    // For now, let's add some example dates
    final prefs = await SharedPreferences.getInstance();
    // TODO: Replace with actual match data from your API
    setState(() {
      _matchDays = {
        DateTime.now().add(const Duration(days: 3)): ['Match'],
        DateTime.now().add(const Duration(days: 7)): ['Match'],
        DateTime.now().add(const Duration(days: 14)): ['Match'],
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CommonLayout(
      selectedIndex: 1,
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            daysOfWeekHeight: 25.0, // Add this line to increase the height
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: (day) {
              return _matchDays[day] ?? [];
            },
            calendarStyle: CalendarStyle(
              markersAlignment: Alignment.bottomCenter,
              markerDecoration: const BoxDecoration(
                color: Color(0xFFFFE6AC),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFFFFE6AC),  // Now using same color for both modes
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.black,  // Black text for selected date
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              titleTextStyle: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 17.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}