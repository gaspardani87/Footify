import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'common_layout.dart';
import 'package:provider/provider.dart';
import 'providers/firebase_provider.dart';
import 'services/team_matches_service.dart';

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
  int _matchCount = 0;
  DateTime? _hoveredDay;

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
      _matchDays = {}; // Clear any existing matches
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

    // Use our TeamMatchesService to get team matches
    try {
      if(!ModalRoute.of(context)!.isCurrent) return;
      
      debugPrint('Requesting matches for team ID: $favoriteTeamId');
      debugPrint('Using endpoint: ${TeamMatchesService.getEndpointUrl(favoriteTeamId)}');
      
      final data = await TeamMatchesService.getTeamMatches(favoriteTeamId);
      
      // Check for error response
      if (data.containsKey('error') && data['error'] != null) {
        debugPrint('Error from TeamMatchesService: ${data['error']}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // Show error to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load matches: ${data['error']}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      // Check if matches key exists and is not null
      final matches = data['matches'];
      if (matches == null) {
        debugPrint('Error: No matches key in API response');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      debugPrint('Found ${matches.length} matches');
      
      // Log first and last match dates for debugging
      if (matches.isNotEmpty) {
        try {
          final firstMatch = matches.first;
          final lastMatch = matches.last;
          final firstDate = DateTime.parse(firstMatch['utcDate']).toLocal();
          final lastDate = DateTime.parse(lastMatch['utcDate']).toLocal();
          debugPrint('Date range: ${firstDate.toString()} to ${lastDate.toString()}');
          
          // Count past matches
          final now = DateTime.now();
          final pastMatches = matches.where((match) => 
            DateTime.parse(match['utcDate']).toLocal().isBefore(now)).toList();
          debugPrint('Past matches: ${pastMatches.length}');
          
          // Count future matches
          final futureMatches = matches.where((match) => 
            DateTime.parse(match['utcDate']).toLocal().isAfter(now)).toList();
          debugPrint('Future matches: ${futureMatches.length}');
        } catch (e) {
          debugPrint('Error analyzing match dates: $e');
        }
      }
      
      // Process matches to group by date
        final Map<DateTime, List<dynamic>> matchDays = {};
        
        for (var match in matches) {
        // Check for required match data
        if (match['utcDate'] == null) {
          debugPrint('Match missing utcDate field, skipping');
          continue;
        }
        
        try {
          final matchDate = DateTime.parse(match['utcDate']).toLocal();
          final dateKey = DateTime(matchDate.year, matchDate.month, matchDate.day);
          
          if (!matchDays.containsKey(dateKey)) {
            matchDays[dateKey] = [];
          }
          matchDays[dateKey]!.add(match);
        } catch (e) {
          debugPrint('Error processing match: $e');
          // Continue with next match
        }
      }

      debugPrint('Processed ${matchDays.keys.length} unique match days');

      if (mounted) {
        setState(() {
          _matchDays = matchDays;
          _matchCount = matches.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading matches: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading matches: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
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
          final formattedDate = 
              '${matchTime.year}-${matchTime.month.toString().padLeft(2, '0')}-${matchTime.day.toString().padLeft(2, '0')}';
              
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

          // Get competition name if available
          String competition = '';
          if (match['competition'] != null && match['competition']['name'] != null) {
            competition = match['competition']['name'];
          }

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text('$homeTeam $matchResult $awayTeam'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (competition.isNotEmpty)
                    Text('Competition: $competition'),
                  Text(isPastMatch ? 'Played: $formattedDate at $formattedTime' : 'Time: $formattedDate at $formattedTime'),
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
      child: Column(
        children: [
          Row(
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
          if (_matchCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Loaded $_matchCount matches',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
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
  
  // Safe method to update hovered day without affecting focused day
  void _updateHoveredDay(DateTime? day) {
    if (mounted) {
      setState(() {
        _hoveredDay = day;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<FirebaseProvider>(context);
    final isLoggedIn = provider.userData != null;

    // Calculate the range of possible dates
    final firstDay = DateTime.now().subtract(const Duration(days: 365 * 2)); // 2 years ago
    final lastDay = DateTime.now().add(const Duration(days: 365)); // 1 year in the future

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
            firstDay: firstDay,
            lastDay: lastDay,
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
            onPageChanged: (focusedDay) {
              // When page changes, update the focused day without resetting the selected day
              setState(() {
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
              // Custom day builder with hover effect
              defaultBuilder: (context, day, focusedDay) {
                final isToday = isSameDay(day, DateTime.now());
                final isSelected = _selectedDay != null && isSameDay(day, _selectedDay!);
                final isHovered = _hoveredDay != null && isSameDay(day, _hoveredDay!);
                
                // Show events/markers
                final events = _matchDays[DateTime(day.year, day.month, day.day)] ?? [];
                final hasEvents = events.isNotEmpty;
                
                // Background color based on state
                Color? backgroundColor;
                if (isSelected) {
                  backgroundColor = const Color(0xFFFFE6AC);
                } else if (isHovered) {
                  backgroundColor = isDarkMode ? Colors.grey[800] : Colors.grey[300]; // Hover effect
                } else if (isToday) {
                  backgroundColor = isDarkMode ? Colors.grey[700] : Colors.grey[200];
                }
                
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _updateHoveredDay(day),
                  onExit: (_) => _updateHoveredDay(null),
                  child: Container(
                    height: 48, // Fixed height for all cells
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.black : null,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 8, // Fixed space for dot or empty space
                          child: hasEvents 
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null, // Empty space if no events
                        ),
                      ],
                    ),
                  ),
                );
              },
              
              // Apply the same hover effect to outside days
              outsideBuilder: (context, day, focusedDay) {
                final isHovered = _hoveredDay != null && isSameDay(day, _hoveredDay!);
                
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _updateHoveredDay(day),
                  onExit: (_) => _updateHoveredDay(null),
                  child: Container(
                    height: 48, // Fixed height for all cells
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(4.0),
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isHovered ? (isDarkMode ? Colors.grey[800] : Colors.grey[300]) : null,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8), // Fixed space to match other cells
                      ],
                    ),
                  ),
                );
              },
              
              // Apply hover effect to today's date
              todayBuilder: (context, day, focusedDay) {
                final isSelected = _selectedDay != null && isSameDay(day, _selectedDay!);
                final isHovered = _hoveredDay != null && isSameDay(day, _hoveredDay!);
                
                // Show events/markers
                final events = _matchDays[DateTime(day.year, day.month, day.day)] ?? [];
                final hasEvents = events.isNotEmpty;
                
                Color backgroundColor;
                if (isSelected) {
                  backgroundColor = const Color(0xFFFFE6AC);
                } else if (isHovered) {
                  backgroundColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
                } else {
                  backgroundColor = isDarkMode ? Colors.grey[700]! : Colors.grey[200]!;
                }
                
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _updateHoveredDay(day),
                  onExit: (_) => _updateHoveredDay(null),
                  child: Container(
                    height: 48, // Fixed height for all cells
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isSelected ? Colors.black : null,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 8, // Fixed space for dot or empty space
                          child: hasEvents 
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null, // Empty space if no events
                        ),
                      ],
                    ),
                  ),
                );
              },
              
              // Apply hover effect to selected dates
              selectedBuilder: (context, day, focusedDay) {
                final isHovered = _hoveredDay != null && isSameDay(day, _hoveredDay!);
                
                // Show events/markers
                final events = _matchDays[DateTime(day.year, day.month, day.day)] ?? [];
                final hasEvents = events.isNotEmpty;
                
                Color backgroundColor = isHovered 
                  ? const Color(0xFFFFCD6B) // Slightly different shade when selected AND hovered
                  : const Color(0xFFFFE6AC);
                
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => _updateHoveredDay(day),
                  onExit: (_) => _updateHoveredDay(null),
                  child: Container(
                    height: 48, // Fixed height for all cells
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 8, // Fixed space for dot or empty space
                          child: hasEvents 
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null, // Empty space if no events
                        ),
                      ],
                    ),
                  ),
                );
              },
              
              // We don't need marker builder since we're incorporating markers into our day builders
              markerBuilder: null,
            ),
            calendarStyle: CalendarStyle(
              // Completely disable the default marker system to prevent duplicate dots
              markersAutoAligned: false,
              markersOffset: const PositionedOffset(),
              markersMaxCount: 0,
              markerSize: 0,
              markersAnchor: 0.0,
              
              // We're not using these decorations anymore since we have custom builders
              todayDecoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.black,  // Black text for selected date
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true, // Allow user to switch between month/week/2-week views
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
                'No matches found for $_favoriteTeamName',
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