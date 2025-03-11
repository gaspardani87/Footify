import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'common_layout.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final favoriteTeamId = prefs.getString('favorite_team_id');
    
    debugPrint('Favorite Team ID: $favoriteTeamId'); // Debug print
    
    if (favoriteTeamId == null) {
      debugPrint('No favorite team selected!'); // Debug print
      return;
    }

    // API configuration
    const proxyUrl = 'https://thingproxy.freeboard.io/fetch/';
    final apiUrl = 'https://api.football-data.org/v4/teams/$favoriteTeamId/matches';
    
    debugPrint('Requesting matches from: $apiUrl'); // Debug print

    try {
      final response = await http.get(
        Uri.parse('$proxyUrl$apiUrl'),
        headers: {
          'X-Auth-Token': '4c553fac5d704101906782d1ecbe1b12',
          'x-cors-api-key': 'temp_b7020b5f16680aae2a61be69685f4115'
        },
      );

      debugPrint('Response status code: ${response.statusCode}'); // Debug print
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Received data: ${data.toString().substring(0, 100)}...'); // Debug print first 100 chars
        
        final matches = data['matches'] as List;
        
        final Map<DateTime, List<dynamic>> matchDays = {};
        
        for (var match in matches) {
          final matchDate = DateTime.parse(match['utcDate']).add(const Duration(hours: 1));
          final dateKey = DateTime(matchDate.year, matchDate.month, matchDate.day);
          
          if (!matchDays.containsKey(dateKey)) {
            matchDays[dateKey] = [];
          }
          matchDays[dateKey]!.add(match);
        }

        setState(() {
          _matchDays = matchDays;
        });
      }
    } catch (e) {
      debugPrint('Error loading matches: $e');
    }
  }

  Widget _buildMatchList() {
    if (_selectedDay == null) return Container();
    
    final selectedMatches = _matchDays[DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day
    )] ?? [];

    if (selectedMatches.isEmpty) return Container();

    return Expanded(
      child: ListView.builder(
        itemCount: selectedMatches.length,
        itemBuilder: (context, index) {
          final match = selectedMatches[index];
          final homeTeam = match['homeTeam']['name'];
          final awayTeam = match['awayTeam']['name'];
          final matchTime = DateTime.parse(match['utcDate'])
              .add(const Duration(hours: 1))
              .toLocal();
          final formattedTime = 
              '${matchTime.hour.toString().padLeft(2, '0')}:${matchTime.minute.toString().padLeft(2, '0')}';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('$homeTeam vs $awayTeam'),
              subtitle: Text('Time: $formattedTime'),
            ),
          );
        },
      ),
    );
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
                color: Colors.green,  // Changed from Color(0xFFFFE6AC) to green
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,  // Show only one marker per day
              markerSize: 8.0,     // Make the marker slightly bigger
              todayDecoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Color(0xFFFFE6AC),
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
          _buildMatchList(),
        ],
      ),
    );
  }
}