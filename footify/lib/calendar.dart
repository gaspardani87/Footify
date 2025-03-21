import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'common_layout.dart';
import 'package:provider/provider.dart';
import 'providers/firebase_provider.dart';

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
  bool _isLoading = true;
  String _favoriteTeamName = '';

  @override
  void initState() {
    super.initState();
    // Load matches after the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMatchDays();
    });
  }

  Future<void> _loadMatchDays() async {
    setState(() {
      _isLoading = true;
    });
    
    // Get the Firebase provider
    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    final userData = provider.userData;
    
    // Get favorite team ID from user data
    final String? favoriteTeamId = userData?['favoriteTeamId'];
    final String? favoriteTeamName = userData?['favoriteTeam'];
    
    debugPrint('Favorite Team ID: $favoriteTeamId'); 
    debugPrint('Favorite Team Name: $favoriteTeamName');
    
    if (favoriteTeamId == null || favoriteTeamId.isEmpty) {
      debugPrint('No favorite team selected!');
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Store the team name for display in the legend
    setState(() {
      _favoriteTeamName = favoriteTeamName ?? 'your favorite team';
    });

    // Use Firebase Functions to get team matches
    try {
      // First, make sure the FootballApiService is initialized
      if(!ModalRoute.of(context)!.isCurrent) return;
      
      // API configuration
      const proxyUrl = 'https://thingproxy.freeboard.io/fetch/';
      final apiUrl = 'https://api.football-data.org/v4/teams/$favoriteTeamId/matches';
      
      debugPrint('Requesting matches from: $apiUrl');

      final response = await http.get(
        Uri.parse('$proxyUrl$apiUrl'),
        headers: {
          'X-Auth-Token': '4c553fac5d704101906782d1ecbe1b12',
          'x-cors-api-key': 'temp_b7020b5f16680aae2a61be69685f4115'
        },
      );

      debugPrint('Response status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Received data: ${data.toString().substring(0, min(100, data.toString().length))}...');
        
        final matches = data['matches'] as List;
        
        final Map<DateTime, List<dynamic>> matchDays = {};
        
        for (var match in matches) {
          final matchDate = DateTime.parse(match['utcDate']).toLocal();
          final dateKey = DateTime(matchDate.year, matchDate.month, matchDate.day);
          
          if (!matchDays.containsKey(dateKey)) {
            matchDays[dateKey] = [];
          }
          matchDays[dateKey]!.add(match);
        }

        if (mounted) {
          setState(() {
            _matchDays = matchDays;
            _isLoading = false;
          });
        }
      } else {
        debugPrint('Failed to load matches: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading matches: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          final matchTime = DateTime.parse(match['utcDate']).toLocal();
          final formattedTime = 
              '${matchTime.hour.toString().padLeft(2, '0')}:${matchTime.minute.toString().padLeft(2, '0')}';
              
          // Check if match is in the past
          final isPastMatch = matchTime.isBefore(DateTime.now());
          
          // For past matches, get the score if available
          String matchResult = 'vs';
          if (isPastMatch && match['score'] != null) {
            final score = match['score'];
            // Check if full time score is available
            if (score['fullTime'] != null && 
                score['fullTime']['home'] != null && 
                score['fullTime']['away'] != null) {
              final homeScore = score['fullTime']['home'];
              final awayScore = score['fullTime']['away'];
              matchResult = '$homeScore - $awayScore';
            }
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('$homeTeam $matchResult $awayTeam'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isPastMatch ? 'Played at: $formattedTime' : 'Time: $formattedTime'),
                  if (match['status'] != null)
                    Text('Status: ${match['status']}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  // Build calendar marker legend
  Widget _buildLegend(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '- $_favoriteTeamName match',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // Method to jump to today's date
  void _goToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<FirebaseProvider>(context);
    final isLoggedIn = provider.userData != null;

    return CommonLayout(
      selectedIndex: 1,
      child: Column(
        children: [
          // Add "Today" button above the calendar
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _goToToday,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Today'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFE6AC),
                  ),
                ),
              ],
            ),
          ),
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2025, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            daysOfWeekHeight: 25.0,
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
              return _matchDays[DateTime(day.year, day.month, day.day)] ?? [];
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: CalendarStyle(
              markersAlignment: Alignment.bottomCenter,
              markerDecoration: const BoxDecoration(
                color: Colors.white,  // White dot for favorite team matches
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
              formatButtonVisible: false, // Remove the format button
              titleCentered: true,
              formatButtonShowsNext: false,
              titleTextStyle: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 17.0,
              ),
            ),
          ),
          
          // Add legend if user is logged in and has a favorite team
          if (isLoggedIn && _matchDays.isNotEmpty)
            _buildLegend(isDarkMode),
            
          // Show loading indicator if loading matches
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (!isLoggedIn)
            // Show message if user is not logged in
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Log in and set your favorite team to see your team\'s matches in the calendar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            )
          else if (_matchDays.isEmpty && !_isLoading)
            // Show message if no matches found
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No upcoming matches found for $_favoriteTeamName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            
          _buildMatchList(),
        ],
      ),
    );
  }
}

// Helper function for string trimming in debug prints
int min(int a, int b) => a < b ? a : b;