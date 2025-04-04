import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'common_layout.dart';
import 'package:provider/provider.dart';
import 'providers/firebase_provider.dart';
import 'services/team_matches_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'services/message_service.dart';
import 'package:intl/intl.dart'; // Add this for DateFormat
import 'package:flutter/foundation.dart' show kIsWeb; // Add this for kIsWeb

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
      _favoriteTeamName = favoriteTeamName ?? AppLocalizations.of(context)!.yourFavoriteTeam;
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
          // Show error to user using MessageService instead of SnackBar
          MessageService.showMessage(
            context, 
            message: '${AppLocalizations.of(context)!.failedToLoadMatches}'.replaceAll('{error}', '${data['error']}'),
            type: MessageType.error,
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
        // Show error to user using MessageService instead of SnackBar
        MessageService.showMessage(
          context, 
          message: 'Error loading matches: $e',
          type: MessageType.error,
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

    // Helper function for image URLs (copied from dashboard)
    String _getProxiedImageUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      // If the URL is already a Firebase storage URL, use it directly
      if (url.startsWith('https://firebasestorage.googleapis.com')) {
        return url;
      }
      
      // Use the proxy image endpoint for external URLs
      // Ensure kIsWeb is checked for web builds
      if (kIsWeb) {
        // Optional: Add quality parameter if needed for web proxy
        return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(url)}';
      } else {
        // Native platforms might not need the proxy, or use a different one
        return url; // Assuming direct URL works for native for now
      }
    }
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // --- Start: Logo replacement logic from dashboard.dart ---
    // Jobb minőségű helyettesítő logók a bajnokságokhoz
    Map<int, String> replacementLogos = {
      2013: 'https://upload.wikimedia.org/wikipedia/en/0/04/Campeonato_Brasileiro_S%C3%A9rie_A.png', // Brasileiro Série A
      2018: 'https://static.wikia.nocookie.net/future/images/8/84/Euro_2028_Logo_Concept_v2.png/revision/latest?cb=20231020120018', // European Championship
      2003: 'https://upload.wikimedia.org/wikipedia/commons/4/46/Eredivisie_nuovo_logo.png', // Eredivisie
      2000: 'https://upload.wikimedia.org/wikipedia/en/thumb/1/17/2026_FIFA_World_Cup_emblem.svg/1200px-2026_FIFA_World_Cup_emblem.svg.png', // FIFA World Cup
      2015: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Ligue1_Uber_Eats_logo.png/1200px-Ligue1_Uber_Eats_logo.png', // Ligue 1 (nagyobb felbontás)
      2019: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/Serie_A_logo_2022.svg/1200px-Serie_A_logo_2022.svg.png', // Serie A
      2014: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/LaLiga_logo_2023.svg/2560px-LaLiga_logo_2023.svg.png', // LaLiga
      2021: 'https://www.sportmonks.com/wp-content/uploads/2024/08/Premier_League_Logo-1.png', // Premier League 
      2152: 'https://upload.wikimedia.org/wikipedia/en/thumb/a/a1/Copa_Libertadores_logo.svg/1200px-Copa_Libertadores_logo.svg.png', // Copa Libertadores
      2001: 'https://assets-us-01.kc-usercontent.com/31dbcbc6-da4c-0033-328a-d7621d0fa726/8e5c2681-8c90-4c64-a79d-2a4fa17834c7/UEFA_Champions_League_Logo.png', // Champions League
      2002: 'https://upload.wikimedia.org/wikipedia/en/thumb/d/df/Bundesliga_logo_%282017%29.svg/1200px-Bundesliga_logo_%282017%29.svg.png', // Bundesliga
      2017: 'https://news.22bet.com/wp-content/uploads/2023/11/liga-portugal-logo-white.png', // Primeira Liga
    };
    
    // Sötét témájú verziók a világos módban nem jól látható logókhoz
    Map<int, String> darkVersionLogos = {
      2021: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Premier_League_Logo.svg/1200px-Premier_League_Logo.svg.png', // Premier League (sötét verzió)
      2001: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f5/UEFA_Champions_League.svg/1200px-UEFA_Champions_League.svg.png', // Champions League (sötét verzió)
      2017: 'https://cdn.freelogovectors.net/wp-content/uploads/2021/08/primeira-logo-liga-portugal-freelogovectors.net_.png', // Primeira Liga (sötét verzió)
    };
    
    // Világos témájú verziók a sötét módhoz
    Map<int, String> lightVersionLogos = {
      2021: 'https://www.sportmonks.com/wp-content/uploads/2024/08/Premier_League_Logo-1.png', // Premier League (fehér verzió)
      2017: 'https://news.22bet.com/wp-content/uploads/2023/11/liga-portugal-logo-white.png', // Primeira Liga (fehér verzió)
      // Add Champions League white version if available, or rely on ColorFiltered below
    };
    
     // Segédfüggvény a hálózati kép megjelenítéséhez (Generic part from dashboard)
    Widget _getNetworkImageWidget(String? logoUrl, bool isDarkMode) {
      if (logoUrl == null || logoUrl.isEmpty) {
        return Icon(
          Icons.sports_soccer, 
          size: 24,
          color: isDarkMode ? Colors.white70 : Colors.black54,
        );
      }
      
      String finalUrl = _getProxiedImageUrl(logoUrl); // Use the calendar's proxy function
      
      return Image.network(
        finalUrl,
        fit: BoxFit.contain,
        width: 24,
        height: 24,
        headers: kIsWeb ? {'Origin': 'null'} : null, // Add headers for web CORS if needed
        errorBuilder: (context, error, stackTrace) {
          print("Original logo load error: $error");
          return Icon(
            Icons.sports_soccer, 
            size: 24,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          );
        },
      );
    }
    
    // Logo builder function (adapted from dashboard)
    Widget _buildCompetitionLogoImage(int? competitionId, String? logoUrl, bool isDarkMode) {
       if (competitionId == null) {
         return _getNetworkImageWidget(logoUrl, isDarkMode);
       }
       
      // A problémás ligák világos módban sötét verziójú képet használnak
      if (!isDarkMode && darkVersionLogos.containsKey(competitionId)) {
        return _getNetworkImageWidget(darkVersionLogos[competitionId], isDarkMode);
      }
      
      // A problémás ligák sötét módban világos/fehér verziójú képet használnak
      if (isDarkMode && lightVersionLogos.containsKey(competitionId)) {
         return _getNetworkImageWidget(lightVersionLogos[competitionId], isDarkMode);
      }
      
      // Eredivisie esetén fehérre színezzük sötét módban
      if (competitionId == 2003 && isDarkMode && replacementLogos.containsKey(competitionId)) {
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          child: _getNetworkImageWidget(replacementLogos[competitionId], isDarkMode),
        );
      }
      
      // Champions League esetén fehérre színezzük sötét módban
      if (competitionId == 2001 && isDarkMode) {
        String? clLogo = logoUrl ?? replacementLogos[competitionId];
         if (clLogo != null) {
           return ColorFiltered(
             colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
             child: _getNetworkImageWidget(clLogo, isDarkMode),
           );
         }
      }
      
      // Ellenőrizzük, hogy van-e helyettesítő online kép
      if (replacementLogos.containsKey(competitionId)) {
        return _getNetworkImageWidget(replacementLogos[competitionId], isDarkMode);
      }
      
      // Minden más esetben az eredeti logót használjuk
      return _getNetworkImageWidget(logoUrl, isDarkMode);
    }
    // --- End: Logo replacement logic ---

    return Expanded(
      child: ListView.builder(
        itemCount: selectedMatches.length,
        itemBuilder: (context, index) {
          final match = selectedMatches[index];
          
          // Extract data with appropriate null checks
          final Map<String, dynamic> competition = match['competition'] ?? {'name': 'Unknown'};
          final Map<String, dynamic> homeTeam = match['homeTeam'] ?? {'name': 'Home'};
          final Map<String, dynamic> awayTeam = match['awayTeam'] ?? {'name': 'Away'};
          
          // Extract competition ID safely
          final int? competitionId = competition['id'] is int ? competition['id'] : null;
          
          // Extract logos with null checks
          final String? competitionLogo = competition['emblem'];
          final String? homeTeamLogo = homeTeam['crest'];
          final String? awayTeamLogo = awayTeam['crest'];

          final matchTime = DateTime.parse(match['utcDate']).toLocal();
          final formattedTime = 
              '${matchTime.hour.toString().padLeft(2, '0')}:${matchTime.minute.toString().padLeft(2, '0')}';
          final formattedDate = 
              '${matchTime.year}-${matchTime.month.toString().padLeft(2, '0')}-${matchTime.day.toString().padLeft(2, '0')}';
              
          // Check if match is in the past
          final isPastMatch = matchTime.isBefore(DateTime.now());
          
          // For past matches, get the score if available
          var homeScore, awayScore;
          if (isPastMatch && match['score'] != null) {
            final score = match['score'];
            // Check if full time score is available
            if (score['fullTime'] != null && 
                score['fullTime']['home'] != null && 
                score['fullTime']['away'] != null) {
              homeScore = score['fullTime']['home'];
              awayScore = score['fullTime']['away'];
            }
          }
          
          final hasScore = homeScore != null && awayScore != null;
          final scoreText = hasScore ? '$homeScore - $awayScore' : 'vs';
          final String matchStatus = match['status'] ?? '';
          
          // --- Start of Copied/Adapted Structure from _buildMatchCard ---
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4.0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Competition Header (Optional, but good for context)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), // Reduced bottom padding
                  child: Row(
                    children: [
                       if (competitionLogo != null && competitionLogo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildCompetitionLogoImage(
                            competitionId, 
                            competitionLogo, 
                            isDarkMode
                          ),
                        ),
                      Expanded(
                        child: Text(
                          competition['name'] ?? 'Unknown Competition',
                          style: TextStyle(
                            color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black87, // Conditional Color
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Display status if not 'vs' (e.g., FT, HT)
                      if(scoreText != 'vs' && matchStatus.isNotEmpty)
                         Text(
                           matchStatus,
                           style: TextStyle(
                             color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                             fontSize: 12,
                           ),
                         ),
                    ],
                  ),
                ),
                
                // Main Match Info Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Home Team Column
                      Expanded( // Use Expanded for flexible sizing
                        child: Column(
                          children: [
                            homeTeamLogo != null && homeTeamLogo.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _getProxiedImageUrl(homeTeamLogo),
                                      width: 50, // Slightly smaller logos
                                      height: 50,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 50,
                                        height: 50,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.sports_soccer, size: 24),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.sports_soccer, size: 24),
                                  ),
                            const SizedBox(height: 8),
                            Text(
                              homeTeam['shortName']?.isNotEmpty == true 
                                ? homeTeam['shortName'] 
                                : homeTeam['name'] ?? 'Home Team', // Fallback to name
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      
                      // Score/Time Column
                      Padding( // Add padding around score/time
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                scoreText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Don't show date, as it's implicit from calendar selection
                            // Text(
                            //   formattedDate,
                            //   style: TextStyle(
                            //     color: isDarkMode ? Colors.white70 : Colors.black54,
                            //     fontSize: 12,
                            //   ),
                            // ),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Away Team Column
                       Expanded( // Use Expanded for flexible sizing
                        child: Column(
                          children: [
                            awayTeamLogo != null && awayTeamLogo.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _getProxiedImageUrl(awayTeamLogo),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 50,
                                        height: 50,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.sports_soccer, size: 24),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.sports_soccer, size: 24),
                                  ),
                            const SizedBox(height: 8),
                            Text(
                              awayTeam['shortName']?.isNotEmpty == true 
                                ? awayTeam['shortName'] 
                                : awayTeam['name'] ?? 'Away Team', // Fallback to name
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Venue Row (Optional, uncomment if needed)
                // if (match['venue'] != null)
                //   Padding(
                //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), // Added padding
                //     child: Row(
                //       mainAxisAlignment: MainAxisAlignment.center,
                //       children: [
                //         Icon(
                //           Icons.location_on,
                //           size: 16,
                //           color: isDarkMode ? Colors.white70 : Colors.black54,
                //         ),
                //         const SizedBox(width: 4),
                //         Flexible(
                //           child: Text(
                //             match['venue'] ?? 'Venue not available',
                //             style: TextStyle(
                //               color: isDarkMode ? Colors.white70 : Colors.black54,
                //               fontSize: 14,
                //             ),
                //             overflow: TextOverflow.ellipsis,
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
              ],
            ),
          );
          // --- End of Copied/Adapted Structure ---
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
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white : Colors.black,
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
                  label: Text(AppLocalizations.of(context)!.today),
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
            daysOfWeekHeight: 24.0,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                fontSize: 12,
              ),
              weekendStyle: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                fontSize: 12,
              ),
            ),
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
                  child: SizedBox(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(2.0),
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
                        if (hasEvents)
                          Positioned(
                            bottom: 2,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.white : Colors.black, // Conditional dot color
                                shape: BoxShape.circle,
                              ),
                            ),
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
                  child: SizedBox(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            color: isHovered ? (isDarkMode ? Colors.grey[800] : Colors.grey[300]) : null,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                            ),
                          ),
                        ),
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
                  child: SizedBox(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(2.0),
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
                        if (hasEvents)
                          Positioned(
                            bottom: 2,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.white : Colors.black, // Conditional dot color
                                shape: BoxShape.circle,
                              ),
                            ),
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
                  child: SizedBox(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(2.0),
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
                        if (hasEvents)
                          Positioned(
                            bottom: 2,
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.white : Colors.black, // Conditional dot color
                                shape: BoxShape.circle,
                              ),
                            ),
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
              formatButtonVisible: false, // Hide the format button
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
                AppLocalizations.of(context)!.noMatchesFound,
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