import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'common_layout.dart';
import 'providers/firebase_provider.dart';
import 'services/dashboard_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'team_details.dart';
import 'profile.dart';
import 'services/football_api_service.dart' as football_api;
import 'dart:async';
import 'dart:math';

// Add ShimmerLoading widget class after the imports and before the DashboardPage class
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    Key? key,
    required this.child,
    required this.isLoading,
  }) : super(key: key);

  @override
  _ShimmerLoadingState createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final shimmerGradient = LinearGradient(
      colors: [
        isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
        isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
      ],
      stops: const [0.1, 0.3, 0.4],
    );

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return shimmerGradient.createShader(
              Rect.fromLTWH(
                -_shimmerController.value * bounds.width * 3,
                0,
                bounds.width * 3,
                bounds.height,
              ),
            );
          },
          child: widget.child,
        );
      },
    );
  }
}

// Replace the _buildLoadingCard method
Widget _buildLoadingCard(BuildContext context, String title, {double height = 250}) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
    height: height,
    decoration: BoxDecoration(
      color: isDarkMode ? const Color(0xFF222222) : Colors.grey[200],
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 4.0,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ShimmerLoading(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16.0),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (index) => Container(
                    height: 24.0,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF333333) : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DashboardPage extends StatefulWidget {
  static Completer<bool> dataLoadedCompleter = Completer<bool>();
  
  // Cache management
  static bool _hasInitialDataLoaded = false;
  static DateTime _lastDataRefreshTime = DateTime(2000); // Initial old date
  static const Duration _cacheDuration = Duration(minutes: 30); // 30 minute cache
  
  // Cached data
  static Map<String, List<dynamic>> _cachedMatchesByDate = {};
  static Map<String, dynamic>? _cachedLeagueStandings;
  static Map<String, dynamic>? _cachedNextMatch;
  static Map<String, dynamic>? _cachedNationalTeamNextMatch;
  
  
  static bool get isCacheValid {
    if (!_hasInitialDataLoaded) return false;
    final timeSinceLastRefresh = DateTime.now().difference(_lastDataRefreshTime);
    return timeSinceLastRefresh < _cacheDuration;
  }
  
  /// Reset the loading state for new instances
  static void resetLoadingState() {
    debugPrint('DashboardPage: Resetting loading state...');
    if (dataLoadedCompleter.isCompleted) {
      debugPrint('DashboardPage: Creating new Completer');
      dataLoadedCompleter = Completer<bool>();
    } else {
      debugPrint('DashboardPage: Existing Completer not completed yet');
    }
  }
  
  /// Check if data loading has completed
  static Future<bool> get dataLoaded => dataLoadedCompleter.future;
  
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  // User preferences and data
  bool _isLoading = true;
  bool _isLoadingDateRange = false;
  
  // Date handling and selection
  List<DateTime> _dateRange = [];
  int _currentDateIndex = 0;
  DateTime _selectedDate = DateTime.now();
  
  // Get the current date, either real or demo
  DateTime get _currentDate {
    return DateTime.now();
  }
  
  // Use sample match data when in demo mode and API fails
  void _addSampleMatchData() {
    // This method is no longer used - removed demo mode functionality
  }
  
  // Match data
  Map<String, List<dynamic>> _matchesCache = {};
  List<dynamic> _matchesByDay = [];
  Map<String, dynamic>? _leagueStandings;
  Map<String, dynamic>? _nextMatch;
  Map<String, dynamic>? _nationalTeamNextMatch;
  
  // Add loading state variables at class level
  bool _isLoadingLeagueStandings = true;
  bool _isLoadingNextMatch = true;
  
  @override
  void initState() {
    super.initState();
    
    // Set initial loading states
    _isLoadingLeagueStandings = true;
    _isLoadingNextMatch = true;
    
    // Generate date range centered around current/demo date
    _generateDateRange();
    
    // Set initial date to current/demo date
    _selectedDate = _currentDate;
    
    // Start loading dashboard data
    _loadDashboardData();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  void _generateDateRange() {
    // Generate 21 days from 10 days ago to 10 days in the future
    _dateRange = [];
    
    // Use current date or demo date
    final DateTime today = _currentDate;
    
    // Add dates from 10 days ago to 10 days in the future
    for (int i = -10; i <= 10; i++) {
      _dateRange.add(today.add(Duration(days: i)));
    }
    
    // Set current date index to today (which is at index 10)
    _currentDateIndex = 10;
    _selectedDate = today;
  }
  
  Future<void> _loadDashboardData() async {
    debugPrint('DashboardPage: Starting to load dashboard data...');
    
    // Set all loading flags to true at the start
    setState(() {
      _isLoading = false; // Set to false immediately to show the dashboard
      _isLoadingLeagueStandings = true;
      _isLoadingNextMatch = true;
    });

    try {
      // Check if we can use cached data
      if (DashboardPage.isCacheValid) {
        debugPrint('DashboardPage: Using cached data (valid for ${DashboardPage._cacheDuration.inMinutes} minutes)');
        // Use the cached data
        if (DashboardPage._cachedLeagueStandings != null) {
          _leagueStandings = DashboardPage._cachedLeagueStandings;
          // Reset league standings loading flag when using cached data
          setState(() {
            _isLoadingLeagueStandings = false;
          });
        }
        if (DashboardPage._cachedNextMatch != null) {
          _nextMatch = DashboardPage._cachedNextMatch;
          // Reset next match loading flag when using cached data
          setState(() {
            _isLoadingNextMatch = false;
          });
        }
        if (DashboardPage._cachedNationalTeamNextMatch != null) {
          _nationalTeamNextMatch = DashboardPage._cachedNationalTeamNextMatch;
        }
        _matchesCache = DashboardPage._cachedMatchesByDate;
        
        // Update selected day matches from cache
        _updateSelectedDayMatches();
        
        // Complete the dataLoadedCompleter if not already completed
        if (!DashboardPage.dataLoadedCompleter.isCompleted) {
          debugPrint('DashboardPage: Completing dataLoadedCompleter (using cached data)');
          DashboardPage.dataLoadedCompleter.complete(true);
        }
        return;
      }
      
      debugPrint('DashboardPage: Cache invalid or expired, loading fresh data');
      
      // OPTIMIZATION: Priority loading - first load minimum required data to show UI
      
      // 1. First, load matches for today only to show something quickly
      final today = _formatDate(_currentDate);
      final dayMatchesData = await DashboardService.getMatchesByDate(today);
      if (!dayMatchesData.containsKey('error') && dayMatchesData.containsKey('matches')) {
        _matchesCache[today] = dayMatchesData['matches'];
        _matchesByDay = dayMatchesData['matches'];
      }
      
      // Load user data for personalization if available
      final provider = Provider.of<FirebaseProvider>(context, listen: false);
      final userData = provider.userData;

      // 2. If not logged in, show matches and complete loading
      if (userData == null) {
        debugPrint('DashboardPage: No user data, completing data loading');
        
        // Load matches for date range in background after showing UI
        _loadMatchesForDateRange();
        
        setState(() {
          _isLoading = false;
          _isLoadingLeagueStandings = false;
          _isLoadingNextMatch = false;
        });
        
        // Set cached data
        DashboardPage._cachedMatchesByDate = _matchesCache;
        DashboardPage._hasInitialDataLoaded = true;
        DashboardPage._lastDataRefreshTime = DateTime.now();
        
        // Complete the loading future if not already completed
        if (!DashboardPage.dataLoadedCompleter.isCompleted) {
          debugPrint('DashboardPage: Completing dataLoadedCompleter (no user)');
          DashboardPage.dataLoadedCompleter.complete(true);
        }
        return;
      }

      // 3. Load essential data for logged-in users
      final String? favoriteTeamId = userData['favoriteTeamId'];
      final String? favoriteNationalTeamId = userData['favoriteNationalTeamId'];
      
      // OPTIMIZATION: Single critical request first, then load rest in background
      if (favoriteTeamId != null && favoriteTeamId.isNotEmpty) {
        // Load team's league standings only - this is visually important
        final teamLeagueData = await DashboardService.getTeamLeague(favoriteTeamId);
        if (!teamLeagueData.containsKey('error') && teamLeagueData['standings'] != null) {
          _leagueStandings = teamLeagueData['standings'];
          DashboardPage._cachedLeagueStandings = teamLeagueData['standings'];
          
          // Add matchday info directly to standings object if available
          if (teamLeagueData['league'] != null && 
              teamLeagueData['league']['currentSeason'] != null && 
              teamLeagueData['league']['currentSeason']['currentMatchday'] != null) {
            _leagueStandings ??= {};
            _leagueStandings!['season'] = {
              'currentMatchday': teamLeagueData['league']['currentSeason']['currentMatchday']
            };
          }
          
          // Set league standings loading flag to false after loading data
          _isLoadingLeagueStandings = false;
        } else {
          // Reset loading flag even if there's an error or no data
          _isLoadingLeagueStandings = false;
        }
      } else {
        // If there's no favorite team, we don't need to show league standings loading
        _isLoadingLeagueStandings = false;
      }
      
      // We now have enough data to show a basic dashboard
      // OPTIMIZATION: Mark loading as complete and show UI
      setState(() {
        _isLoading = false;
      });
      
      // Complete loading to signal that dashboard is visible
      if (!DashboardPage.dataLoadedCompleter.isCompleted) {
        debugPrint('DashboardPage: Completing dataLoadedCompleter (with essential data)');
        DashboardPage.dataLoadedCompleter.complete(true);
      }
      
      // OPTIMIZATION: Load remaining data in background without blocking UI
      _loadRemainingDataInBackground(userData);
      
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      // Even on error, we should show dashboard and reset all loading flags
      setState(() {
        _isLoading = false;
        _isLoadingLeagueStandings = false;
        _isLoadingNextMatch = false;
      });
      
      // Complete loading even on error to prevent splash screen hanging
      if (!DashboardPage.dataLoadedCompleter.isCompleted) {
        debugPrint('DashboardPage: Completing dataLoadedCompleter (after error)');
        DashboardPage.dataLoadedCompleter.complete(true);
      }
    }
  }
  
  // Update _loadRemainingDataInBackground to handle loading states properly
  Future<void> _loadRemainingDataInBackground(Map<String, dynamic> userData) async {
    debugPrint('DashboardPage: Loading remaining data in background');
    
    final String? favoriteTeamId = userData['favoriteTeamId'];
    final String? favoriteNationalTeamId = userData['favoriteNationalTeamId'];
    
    try {
      // Load data in parallel with Future.wait for faster loading
      List<Future> loadingTasks = [];
      
      // 1. Load matches for entire date range
      loadingTasks.add(_loadMatchesForDateRange());
      
      // 2. Load league standings for favorite team if available
      if (favoriteTeamId != null && favoriteTeamId.isNotEmpty && 
          DashboardPage._cachedLeagueStandings == null) {
        loadingTasks.add(
          DashboardService.getTeamLeague(favoriteTeamId).then((teamLeagueData) {
            if (!teamLeagueData.containsKey('error') && teamLeagueData['standings'] != null) {
              if (mounted) {
                setState(() {
                  _leagueStandings = teamLeagueData['standings'];
                  _isLoadingLeagueStandings = false; // Set loading to false when data is loaded
                });
              }
              // Add matchday info directly to standings object if available
              if (teamLeagueData['league'] != null && 
                  teamLeagueData['league']['currentSeason'] != null && 
                  teamLeagueData['league']['currentSeason']['currentMatchday'] != null) {
                _leagueStandings ??= {};
                _leagueStandings!['season'] = {
                  'currentMatchday': teamLeagueData['league']['currentSeason']['currentMatchday']
                };
              }
              
              // Cache league standings
              DashboardPage._cachedLeagueStandings = teamLeagueData['standings'];
              debugPrint('DashboardPage: League standings loaded in background');
            } else {
              // Set loading to false even if there's an error or no data
              if (mounted) {
                setState(() {
                  _isLoadingLeagueStandings = false;
                });
              }
            }
          }).catchError((e) {
            debugPrint('DashboardPage: Error loading league standings in background: $e');
            // Set loading to false on error
            if (mounted) {
              setState(() {
                _isLoadingLeagueStandings = false;
              });
            }
          })
        );
      } else {
        // If we're not loading league standings, set loading to false
        if (mounted) {
          setState(() {
            _isLoadingLeagueStandings = false;
          });
        }
      }
      
      // 3. Load next match for favorite team if available
      if (favoriteTeamId != null && favoriteTeamId.isNotEmpty && 
          DashboardPage._cachedNextMatch == null) {
        loadingTasks.add(
          DashboardService.getNextMatch(favoriteTeamId).then((nextMatchData) {
            if (!nextMatchData.containsKey('error') && nextMatchData['match'] != null) {
              if (mounted) {
                setState(() {
                  _nextMatch = nextMatchData['match'];
                  _isLoadingNextMatch = false; // Set loading to false when data is loaded
                });
              }
              // Cache next match
              DashboardPage._cachedNextMatch = nextMatchData['match'];
              debugPrint('DashboardPage: Next match loaded in background');
            } else {
              // Set loading to false even if there's an error or no data
              if (mounted) {
                setState(() {
                  _isLoadingNextMatch = false;
                });
              }
            }
          }).catchError((e) {
            debugPrint('DashboardPage: Error loading next match in background: $e');
            // Set loading to false on error
            if (mounted) {
              setState(() {
                _isLoadingNextMatch = false;
              });
            }
          })
        );
      } else {
        // If we're not loading next match data, set loading to false
        if (mounted) {
          setState(() {
            _isLoadingNextMatch = false;
          });
        }
      }
      
      // 4. Load national team's data if available
      if (favoriteNationalTeamId != null && favoriteNationalTeamId.isNotEmpty && 
          DashboardPage._cachedNationalTeamNextMatch == null) {
        loadingTasks.add(
          DashboardService.getNationalTeamNextMatch(favoriteNationalTeamId).then((nationalTeamMatchData) {
            if (!nationalTeamMatchData.containsKey('error') && nationalTeamMatchData['match'] != null) {
              if (mounted) {
                setState(() {
                  _nationalTeamNextMatch = nationalTeamMatchData['match'];
                  // Update loading state after both club and national team matches are loaded
                  if (_nextMatch == null) {
                    _isLoadingNextMatch = false;
                  }
                });
              }
              // Cache national team next match
              DashboardPage._cachedNationalTeamNextMatch = nationalTeamMatchData['match'];
              debugPrint('DashboardPage: National team next match loaded in background');
            }
          }).catchError((e) {
            debugPrint('DashboardPage: Error loading national team match in background: $e');
          })
        );
      }
      
      // Wait for all tasks to complete
      await Future.wait(loadingTasks);
      
      // Ensure all loading states are set to false after everything is done
      if (mounted) {
        setState(() {
          _isLoadingLeagueStandings = false;
          _isLoadingNextMatch = false;
        });
      }
      
      // Update cache timestamp
      DashboardPage._cachedMatchesByDate = _matchesCache;
      DashboardPage._hasInitialDataLoaded = true;
      DashboardPage._lastDataRefreshTime = DateTime.now();
      
      debugPrint('DashboardPage: Background data loading complete');
    } catch (e) {
      debugPrint('DashboardPage: Error in background data loading: $e');
      // Make sure all loading states are set to false on error
      if (mounted) {
        setState(() {
          _isLoadingLeagueStandings = false;
          _isLoadingNextMatch = false;
        });
      }
    }
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
  
  // Load matches for the date range in two separate API calls (past and future)
  Future<void> _loadMatchesForDateRange() async {
    if (_isLoadingDateRange) return; // Prevent concurrent API calls
    
    setState(() {
      _isLoadingDateRange = true;
      if (_matchesByDay.isEmpty) {
        // Only clear current matches if they aren't already loaded
        _matchesByDay = []; 
      }
    });
    
    try {
      // Today's date will be included in both past and future requests
      final String today = _formatDate(_currentDate);
      
      // Calculate date ranges
      final String tenDaysAgo = _formatDate(_currentDate.subtract(const Duration(days: 10)));
      final String tenDaysLater = _formatDate(_currentDate.add(const Duration(days: 10)));
      
      // Check if we already have sufficient cached data
      if (DashboardPage.isCacheValid && _matchesCache.isNotEmpty) {
        debugPrint('Using cached match data (valid for ${DashboardPage._cacheDuration.inMinutes} minutes)');
        _updateSelectedDayMatches();
        setState(() {
          _isLoadingDateRange = false;
        });
        return;
      }
      
      debugPrint('Loading matches for two date ranges:');
      debugPrint('1. Past: $tenDaysAgo to $today');
      debugPrint('2. Future: $today to $tenDaysLater');
      
      // RATE LIMITING: Only load future matches first, which are more critical
      // Then load past matches only if needed and with a delay to avoid rate limits
      
      // First, load future matches
      final futureMatchesData = await DashboardService.getMatchesForDateRange(today, tenDaysLater);
      
      if (!futureMatchesData.containsKey('error') && futureMatchesData.containsKey('matchesByDate')) {
        // Process future matches first to show upcoming content
        setState(() {
          // Store future days' matches in the cache  
          final Map<String, dynamic> futureMatchesByDate = futureMatchesData['matchesByDate'];
          futureMatchesByDate.forEach((date, matches) {
            debugPrint('Caching ${matches.length} matches for $date (future)');
            _matchesCache[date] = matches;
          });
          
          // Update display with current day matches immediately
          _updateSelectedDayMatches();
        });
        
        // After a delay to avoid rate limits, load past matches if needed
        // Only do this if cache is not already valid (for revisits)
        if (!DashboardPage.isCacheValid) {
          await Future.delayed(const Duration(seconds: 2)); // Rate limiting delay
          
          final pastMatchesData = await DashboardService.getMatchesForDateRange(tenDaysAgo, today);
          
          if (!pastMatchesData.containsKey('error') && pastMatchesData.containsKey('matchesByDate')) {
            setState(() {
              // Store past days' matches in the cache
              final Map<String, dynamic> pastMatchesByDate = pastMatchesData['matchesByDate'];
              pastMatchesByDate.forEach((date, matches) {
                // For today's date, which appears in both responses, combine the matches
                if (date == today && _matchesCache.containsKey(date)) {
                  // Combine matches, making sure to avoid duplicates
                  final List<dynamic> existingMatches = _matchesCache[date]!;
                  final List<dynamic> newMatches = matches;
                  final Set<String> existingMatchIds = existingMatches
                      .map((m) => m['id']?.toString() ?? '')
                      .toSet();
                  
                  final List<dynamic> uniqueNewMatches = newMatches
                      .where((m) => !existingMatchIds.contains(m['id']?.toString() ?? ''))
                      .toList();
                  
                  _matchesCache[date] = [...existingMatches, ...uniqueNewMatches];
                  debugPrint('Combined ${existingMatches.length} + ${uniqueNewMatches.length} matches for $date');
                } else {
                  debugPrint('Caching ${matches.length} matches for $date (past)');
                  _matchesCache[date] = matches;
                }
              });
              
              // Update the display after loading past matches
              _updateSelectedDayMatches();
            });
          }
        }
        
        debugPrint('Successfully loaded matches for the date range');
      } else {
        // If API call failed, try the single-day approach as fallback
        debugPrint('Error loading matches for date range, using fallback');
        await _loadMatchesForDay(_formatDate(_selectedDate));
        
        // Check if we need to add sample data for demo mode
        _addSampleMatchData();
      }
    } catch (e) {
      debugPrint('Exception loading matches for date range: $e');
      // Fallback to single day loading if the range API fails
      await _loadMatchesForDay(_formatDate(_selectedDate));
      
      // Check if we need to add sample data for demo mode
      _addSampleMatchData();
    } finally {
      setState(() {
        _isLoadingDateRange = false;
      });
      
      // Set cached data
      DashboardPage._cachedMatchesByDate = _matchesCache;
      DashboardPage._hasInitialDataLoaded = true;
      DashboardPage._lastDataRefreshTime = DateTime.now();
    }
  }
  
  // Update the displayed matches based on the selected date
  void _updateSelectedDayMatches() {
    final formattedDate = _formatDate(_selectedDate);
    
    setState(() {
      if (_matchesCache.containsKey(formattedDate)) {
        _matchesByDay = _matchesCache[formattedDate]!;
        debugPrint('Using cached matches for $formattedDate: ${_matchesByDay.length} matches');
      } else {
        _matchesByDay = [];
        debugPrint('No cached matches found for $formattedDate');
      }
    });
  }
  
  // This method will only be used as a fallback if the range API fails
  Future<void> _loadMatchesForDay(String date) async {
    debugPrint('Fallback: Loading single day matches for $date');
    setState(() {
      _matchesByDay = []; // Clear while loading
    });
    
    final matchesData = await DashboardService.getMatchesByDate(date);
    if (!matchesData.containsKey('error')) {
      // Debug the response to see what we're getting
      debugPrint('Matches data for $date: ${matchesData.keys.join(', ')}');
      
      setState(() {
        List<dynamic> matches = [];
        
        // Check if we have a 'matches' field (flat list)
        if (matchesData.containsKey('matches') && matchesData['matches'] is List) {
          matches = matchesData['matches'];
          debugPrint('Loaded ${matches.length} matches from flat list for $date');
        } 
        // Check if we have a 'competitions' field (grouped by competition)
        else if (matchesData.containsKey('competitions') && matchesData['competitions'] is List) {
          // Extract matches from each competition
          final List<dynamic> competitions = matchesData['competitions'];
          for (var comp in competitions) {
            if (comp.containsKey('matches') && comp['matches'] is List) {
              matches.addAll(comp['matches']);
            }
          }
          debugPrint('Loaded ${matches.length} matches from competitions for $date');
        }
        
        _matchesByDay = matches;
        
        // Update cache with this day's matches
        _matchesCache[date] = matches;
        
        if (matches.isEmpty) {
          debugPrint('No matches found for $date');
        }
      });
    } else {
      debugPrint('Error loading matches: ${matchesData['error']}');
      setState(() {
        _matchesByDay = [];
      });
    }
  }
  
  void _changeDate(int direction) {
    final newDate = _selectedDate.add(Duration(days: direction));
    final now = _currentDate;
    
    // Check if the new date is outside the current date range
    // (more than 10 days in the past or future from today)
    bool needsRangeRefresh = false;
    if (newDate.difference(now).inDays < -10 || newDate.difference(now).inDays > 10) {
      needsRangeRefresh = true;
    }
    
    setState(() {
      _selectedDate = newDate;
      
      if (needsRangeRefresh) {
        // Generate a new date range if we're going outside the 20-day window
        _generateDateRange();
        // Override the selected date since _generateDateRange resets to today
        _selectedDate = newDate;
        
        // Find the appropriate index for the selected date in the new range
        _currentDateIndex = _dateRange.indexWhere(
          (date) => date.year == newDate.year && 
                    date.month == newDate.month && 
                    date.day == newDate.day
        );
        
        // If somehow the date isn't in the range, use the first or last date
        if (_currentDateIndex == -1) {
          if (newDate.isBefore(_dateRange.first)) {
            _currentDateIndex = 0;
            _selectedDate = _dateRange.first;
          } else {
            _currentDateIndex = _dateRange.length - 1;
            _selectedDate = _dateRange.last;
          }
        }
      } else {
        // Just update the current index within the existing range
        _currentDateIndex = _dateRange.indexWhere(
          (date) => date.year == newDate.year && 
                    date.month == newDate.month && 
                    date.day == newDate.day
        );
      }
    });
    
    if (needsRangeRefresh) {
      // Load new date range data if we've moved outside the current range
      _loadMatchesForDateRange();
    } else {
      // Just display matches from cache since we should have all data
      _updateSelectedDayMatches();
    }
  }
  
  void _selectDate(DateTime date, int index) {
    if (index == _currentDateIndex) return;
    
    final now = _currentDate;
    
    // Check if the selected date is outside the current date range
    // (more than 10 days in the past or future from today)
    bool needsRangeRefresh = false;
    if (date.difference(now).inDays < -10 || date.difference(now).inDays > 10) {
      needsRangeRefresh = true;
    }
    
    setState(() {
      _selectedDate = date;
      
      if (needsRangeRefresh) {
        // Generate a new date range if we're going outside the 20-day window
        _generateDateRange();
        // Override the selected date since _generateDateRange resets to today
        _selectedDate = date;
        
        // Find the appropriate index for the selected date in the new range
        _currentDateIndex = _dateRange.indexWhere(
          (d) => d.year == date.year && d.month == date.month && d.day == date.day
        );
        
        // If somehow the date isn't in the range, use the first or last date
        if (_currentDateIndex == -1) {
          if (date.isBefore(_dateRange.first)) {
            _currentDateIndex = 0;
            _selectedDate = _dateRange.first;
          } else {
            _currentDateIndex = _dateRange.length - 1;
            _selectedDate = _dateRange.last;
          }
        }
      } else {
        _currentDateIndex = index;
      }
    });
    
    if (needsRangeRefresh) {
      // Load new date range data if we've moved outside the current range
      _loadMatchesForDateRange();
    } else {
      // Always use cached data - we should have all data loaded
      _updateSelectedDayMatches();
    }
  }

  void _navigateToTeamDetails(String teamId, String teamName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailsPage(teamId: teamId, teamName: teamName),
      ),
    );
  }

  // Add utility method for image URLs
  String _getProxiedImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    // If the URL is already a Firebase storage URL, use it directly
    if (url.startsWith('https://firebasestorage.googleapis.com')) {
      return url;
    }
    
    // Use the proxy image endpoint for external URLs
    return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(url)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FirebaseProvider>(context);
    final userData = provider.userData;
    final isLoggedIn = userData != null;
    
    return CommonLayout(
      selectedIndex: 0,
      child: _isLoading 
          ? _buildLoadingView() 
          : !isLoggedIn 
              ? _buildNotLoggedInView() 
              : _buildDashboardContent(userData),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildNotLoggedInView() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.loginToViewDashboard ?? 'Log in to view your personalized dashboard',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE6AC),
                  foregroundColor: Colors.black,
                ),
                child: Text(AppLocalizations.of(context)?.login ?? 'Login'),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)?.upcomingMatches ?? 'Upcoming Matches',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                // Today button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                      _generateDateRange();
                      _currentDateIndex = 10; // Today is at index 10
                    });
                    
                    // Always reload matches when returning to today
                    _loadMatchesForDateRange();
                  },
                  icon: const Icon(Icons.today, size: 16),
                  label: Text(AppLocalizations.of(context)?.today ?? 'Today'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFE6AC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDateSelector(),
            _buildMatchesForDay(),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(Map<String, dynamic> userData) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: Favorite Team and Nation boxes side by side
            Row(
              children: [
                // Favorite Team Box (1/2 width)
                Expanded(
                  flex: 1,
                  child: _buildFavoriteTeamBox(userData),
                ),
                const SizedBox(width: 16),
                // Favorite Nation Box (1/2 width)
                Expanded(
                  flex: 1,
                  child: _buildFavoriteNationBox(userData),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // League standings section (full width)
            if (_leagueStandings != null) 
              _buildLeagueStandingsBox(userData),
            
            const SizedBox(height: 16),
            
            // Next match section (full width)
            if (_nextMatch != null || _nationalTeamNextMatch != null)
              _buildNextMatchBox(userData),
            
            const SizedBox(height: 16),
            
            // All matches section with date selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)?.upcomingMatches ?? 'Upcoming Matches',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                // Today button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime.now();
                      _generateDateRange();
                      _currentDateIndex = 10; // Today is at index 10
                    });
                    
                    // Always reload matches when returning to today
                    _loadMatchesForDateRange();
                  },
                  icon: const Icon(Icons.today, size: 16),
                  label: Text(AppLocalizations.of(context)?.today ?? 'Today'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFFE6AC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDateSelector(),
            _buildMatchesForDay(),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteTeamBox(Map<String, dynamic> userData) {
    final String favoriteTeam = userData['favoriteTeam'] ?? '';
    final String favoriteTeamId = userData['favoriteTeamId'] ?? '';
    final String? teamLogo = userData['favoriteTeamLogo'];
    
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: favoriteTeamId.isNotEmpty 
            ? () => _navigateToTeamDetails(favoriteTeamId, favoriteTeam)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)?.favoriteTeam ?? 'Favorite Team',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFE6AC) : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 60),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    teamLogo != null && teamLogo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            _getProxiedImageUrl(teamLogo),
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.sports_soccer,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.sports_soccer,
                          color: Colors.white,
                          size: 24,
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: favoriteTeam.isNotEmpty
                        ? _buildTeamNameWithWordWrap(favoriteTeam)
                        : Text(
                            AppLocalizations.of(context)?.noTeamSelected ?? 'No team selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A csapatnév szóköznél való töréshez egy új segédfüggvény
  Widget _buildTeamNameWithWordWrap(String teamName) {
    // Megkeressük az első szóközt a sorban, hogy ott törjük a szöveget
    final words = teamName.split(' ');
    
    // Ha csak egy szó van, vagy túl rövid a név, akkor egyszerűen visszaadjuk
    if (words.length <= 1 || teamName.length < 15) {
      return Text(
        teamName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 2,
      );
    }
    
    // Próbáljuk megtalálni a legjobb helyet a törésre
    // Körülbelül a név felénél lévő szóközt keresünk
    int totalLength = teamName.length;
    int middleIndex = totalLength ~/ 2;
    
    // Keressük meg azt a szóközt, amely a legközelebb van a középponthoz
    int bestBreakIndex = 0;
    int minDistance = totalLength;
    
    int currentPosition = 0;
    for (int i = 0; i < words.length - 1; i++) {
      currentPosition += words[i].length + 1; // +1 a szóköz miatt
      int distance = (currentPosition - middleIndex).abs();
      
      if (distance < minDistance) {
        minDistance = distance;
        bestBreakIndex = i;
      }
    }
    
    // Az első sor a 0-tól a bestBreakIndex-ig terjedő szavak
    String firstLine = words.sublist(0, bestBreakIndex + 1).join(' ');
    // A második sor a maradék
    String secondLine = words.sublist(bestBreakIndex + 1).join(' ');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          firstLine,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          secondLine,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFavoriteNationBox(Map<String, dynamic> userData) {
    final String favoriteNation = userData['favoriteNationalTeam'] ?? '';
    final String favoriteNationId = userData['favoriteNationalTeamId'] ?? '';
    
    final Map<String, String> flagUrls = {
      '2106': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Flag_of_Hungary.svg/800px-Flag_of_Hungary.svg.png',
      '759': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Flag_of_Germany.svg/800px-Flag_of_Germany.svg.png',
      '760': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Flag_of_Spain.svg/800px-Flag_of_Spain.svg.png',
      '770': 'https://upload.wikimedia.org/wikipedia/en/thumb/b/be/Flag_of_England.svg/1200px-Flag_of_England.svg.png',
      '764': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Flag_of_Brazil.svg/800px-Flag_of_Brazil.svg.png',
      '762': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Flag_of_Argentina.svg/800px-Flag_of_Argentina.svg.png',
      '773': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Flag_of_France.svg/800px-Flag_of_France.svg.png',
      '784': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Flag_of_Italy.svg/800px-Flag_of_Italy.svg.png',
      '785': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Flag_of_the_Netherlands.svg/800px-Flag_of_the_Netherlands.svg.png',
      '765': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Flag_of_Portugal.svg/800px-Flag_of_Portugal.svg.png',
      '805': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Flag_of_Belgium.svg/800px-Flag_of_Belgium.svg.png',
      '799': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Flag_of_Croatia.svg/800px-Flag_of_Croatia.svg.png',
      '825': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Flag_of_Switzerland.svg/1024px-Flag_of_Switzerland.svg.png',
      '772': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Flag_of_Poland.svg/1280px-Flag_of_Poland.svg.png',
      '776': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Flag_of_Turkey.svg/1280px-Flag_of_Turkey.svg.png',
      '782': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Flag_of_the_Netherlands.svg/1280px-Flag_of_the_Netherlands.svg.png',
      '801': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Flag_of_Australia_%28converted%29.svg/1280px-Flag_of_Australia_%28converted%29.svg.png',
      '794': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Flag_of_Sweden.svg/1280px-Flag_of_Sweden.svg.png',
      '827': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d9/Flag_of_Norway.svg/1280px-Flag_of_Norway.svg.png',
      '793': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9c/Flag_of_Denmark.svg/1280px-Flag_of_Denmark.svg.png',
      '768': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Flag_of_Finland.svg/1280px-Flag_of_Finland.svg.png',
      '767': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Flag_of_Uruguay.svg/1280px-Flag_of_Uruguay.svg.png',
      '758': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Flag_of_Ghana.svg/1280px-Flag_of_Ghana.svg.png',
      '804': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/32/Flag_of_Senegal.svg/1280px-Flag_of_Senegal.svg.png',
      '815': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Flag_of_Morocco.svg/1280px-Flag_of_Morocco.svg.png',
      '854': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Flag_of_Montenegro.svg/1280px-Flag_of_Montenegro.svg.png',
      '840': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/Flag_of_Serbia.svg/1280px-Flag_of_Serbia.svg.png',
      '778': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Flag_of_Romania.svg/1280px-Flag_of_Romania.svg.png',
      '2104': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Flag_of_Bosnia_and_Herzegovina.svg/1280px-Flag_of_Bosnia_and_Herzegovina.svg.png',
      '796': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Flag_of_Austria.svg/1280px-Flag_of_Austria.svg.png',
      '786': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/45/Flag_of_Ireland.svg/1280px-Flag_of_Ireland.svg.png',
      '832': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/10/Flag_of_Scotland.svg/1280px-Flag_of_Scotland.svg.png',
      '833': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Flag_of_Wales.svg/1280px-Flag_of_Wales.svg.png',
      '779': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/Flag_of_South_Korea.svg/1280px-Flag_of_South_Korea.svg.png',
      '780': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Flag_of_Japan.svg/1280px-Flag_of_Japan.svg.png',
      '781': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/Flag_of_Saudi_Arabia.svg/1280px-Flag_of_Saudi_Arabia.svg.png',
      '802': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Flag_of_Palestine.svg/1280px-Flag_of_Palestine.svg.png',
      '791': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Flag_of_the_United_States.svg/1280px-Flag_of_the_United_States.svg.png',
      '769': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Flag_of_Canada.svg/1280px-Flag_of_Canada.svg.png',
      '771': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fc/Flag_of_Mexico.svg/1280px-Flag_of_Mexico.svg.png',
      '828': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b7/Flag_of_Europe.svg/1280px-Flag_of_Europe.svg.png'
    };

    String? flagUrl = favoriteNationId.isNotEmpty ? flagUrls[favoriteNationId] : null;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: favoriteNationId.isNotEmpty 
            ? () => _navigateToTeamDetails(favoriteNationId, favoriteNation)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)?.favoriteNation ?? 'Favorite Nation',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFE6AC) : Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 60),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        image: flagUrl != null ? DecorationImage(
                          image: NetworkImage(flagUrl),
                          fit: BoxFit.cover,
                        ) : null,
                      ),
                      child: flagUrl == null ? const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 24,
                      ) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: favoriteNation.isNotEmpty
                        ? _buildTeamNameWithWordWrap(favoriteNation)
                        : Text(
                            AppLocalizations.of(context)?.noNationSelected ?? 'No nation selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeagueStandingsBox(Map<String, dynamic> userData) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Create a league standings skeleton for loading state
    Widget loadingContent = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'League Standings',
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                width: 60.0,
                height: 24.0,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF333333) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24.0),
          // Standings header placeholder
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: List.generate(
                6,
                (index) => Expanded(
                  flex: index == 1 ? 3 : 1,
                  child: Center(
                    child: Container(
                      width: index == 1 ? 60.0 : 20.0,
                      height: 12.0,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          // Team rows placeholders
          ...List.generate(
            5,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 20.0,
                    height: 20.0,
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF333333) : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 16.0,
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF333333) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),
                  ),
                  ...List.generate(
                    4,
                    (index) => Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          width: 20.0,
                          height: 16.0,
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF333333) : Colors.grey[300],
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    
    // Check if we're in loading state and return loading skeleton with shimmer
    if (_isLoadingLeagueStandings) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ShimmerLoading(
          isLoading: true,
          child: loadingContent,
        ),
      );
    }
    
    final String favoriteTeam = userData['favoriteTeam'] ?? '';
    final String favoriteTeamId = userData['favoriteTeamId'] ?? '';
    
    // Get standings data
    final standings = _leagueStandings?['standings']?[0]?['table'] ?? [];
    final competition = _leagueStandings?['competition'] ?? {};
    final String leagueName = competition['name'] ?? 'League';
    final String? leagueLogo = competition['emblem'];
    
    // Javított mérkőzésnap kinyerés - több lehetséges helyen keressük az adatot
    int matchday = 0;
    
    // 1. Először közvetlenül a leagueStandings season adatából próbáljuk kinyerni
    if (_leagueStandings?['season']?['currentMatchday'] != null) {
      matchday = _leagueStandings!['season']['currentMatchday'];
    } 
    // 2. Azután a competition currentSeason adatából
    else if (competition['currentSeason']?['currentMatchday'] != null) {
      matchday = competition['currentSeason']['currentMatchday'];
    }
    // 3. Vagy közvetlenül a standings adatban is lehet (API függő)
    else if (_leagueStandings?['matchday'] != null) {
      matchday = _leagueStandings!['matchday'];
    }
    
    // Debug információk kiírása a konzolra
    print('League Standings: ${standings.length} teams available');
    print('Matchday: $matchday, Data source: ${_leagueStandings.toString().substring(0, 100 < (_leagueStandings?.toString().length ?? 0) ? 100 : (_leagueStandings?.toString().length ?? 1))}...');
    
    // Find favorite team position
    int favoriteTeamIndex = -1;
    if (standings.isNotEmpty && favoriteTeamId.isNotEmpty) {
      for (int i = 0; i < standings.length; i++) {
        final teamId = standings[i]['team']?['id']?.toString() ?? '';
        if (teamId == favoriteTeamId) {
          favoriteTeamIndex = i;
          print('Found favorite team at position: $favoriteTeamIndex');
          break;
        }
      }
    }
    
    // Get teams to display (favorite, one above, one below)
    List<dynamic> teamsToShow = [];
    if (favoriteTeamIndex != -1) {
      // Add team above if exists
      if (favoriteTeamIndex > 0) {
        teamsToShow.add(standings[favoriteTeamIndex - 1]);
      }
      
      // Add favorite team
      teamsToShow.add(standings[favoriteTeamIndex]);
      
      // Add team below if exists
      if (favoriteTeamIndex < standings.length - 1) {
        teamsToShow.add(standings[favoriteTeamIndex + 1]);
      }
    } else if (standings.isNotEmpty) {
      // If favorite team not found, show top 3
      teamsToShow = standings.take(3).toList();
    }
    
    if (teamsToShow.isEmpty) {
      return Container(); // Return empty container if no teams to show
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // League header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    leagueLogo != null && leagueLogo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            _getProxiedImageUrl(leagueLogo),
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.emoji_events,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: 18,
                        ),
                    const SizedBox(width: 12),
                    Text(
                      leagueName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${AppLocalizations.of(context)?.matchday ?? 'Matchday'} $matchday',
                  style: const TextStyle(
                    color: Color(0xFFFFE6AC),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const SizedBox(width: 30), // Position
                Expanded(
                  flex: 3,
                  child: Text(
                    AppLocalizations.of(context)?.teamColumnHeader ?? 'Team',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    AppLocalizations.of(context)?.matchesColumnHeader ?? 'P',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    AppLocalizations.of(context)?.winsShort ?? 'W',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    AppLocalizations.of(context)?.drawsShort ?? 'D',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    AppLocalizations.of(context)?.lossesShort ?? 'L',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    AppLocalizations.of(context)?.pointsColumnHeader ?? 'Pts',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.grey, height: 20, thickness: 0.5),
          
          // Team rows
          ...teamsToShow.map((team) {
            final position = team['position'];
            final teamName = team['team']['name'];
            final teamId = team['team']['id'].toString();
            final teamCrest = team['team']['crest'];
            final playedGames = team['playedGames'];
            final won = team['won'];
            final draw = team['draw'];
            final lost = team['lost'];
            final points = team['points'];
            
            final bool isFavorite = teamId == favoriteTeamId;
            
            return InkWell(
              onTap: () => _navigateToTeamDetails(teamId, teamName),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: isFavorite ? Colors.grey[800]!.withOpacity(0.3) : null,
                  border: isFavorite 
                      ? Border.all(color: const Color(0xFFFFE6AC), width: 1)
                      : null,
                  borderRadius: isFavorite ? BorderRadius.circular(12) : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        position.toString(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          fontWeight: isFavorite ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          if (teamCrest != null && teamCrest.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  _getProxiedImageUrl(teamCrest),
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => 
                                    const SizedBox(width: 20),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              teamName,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                fontWeight: isFavorite ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        playedGames.toString(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          fontWeight: isFavorite ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        won.toString(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          fontWeight: isFavorite ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        draw.toString(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          fontWeight: isFavorite ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        lost.toString(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          fontWeight: isFavorite ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        points.toString(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNextMatchBox(Map<String, dynamic>? userData) {
    // Show loading animation if data is still loading
    if (_isLoadingNextMatch) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ShimmerLoading(
          isLoading: true,
          child: _buildNextMatchContentSkeleton(),
        ),
      );
    }

    // Debug the current data structure
    debugPrint('Next Match data: $_nextMatch');
    if (_nextMatch != null) {
      // Log the top-level data structure to understand what we're working with
      _nextMatch!.forEach((key, value) {
        debugPrint('Next Match - $key: ${value?.runtimeType}');
      });
    }
    debugPrint('National Team Match data: $_nationalTeamNextMatch');
    
    // Check for valid match data - handle BOTH possible structures
    Map<String, dynamic>? matchToShow;
    bool isNationalTeam = false;
    
    // Adapt to the actual structure - check if match is directly in _nextMatch
    // or nested inside a 'match' property
    bool hasClubMatch = false;
    if (_nextMatch != null) {
      // Match could be directly in _nextMatch
      if (_nextMatch!.containsKey('homeTeam') && _nextMatch!.containsKey('awayTeam')) {
        matchToShow = _nextMatch;
        hasClubMatch = true;
      } 
      // Or inside a 'match' property (as we were checking before)
      else if (_nextMatch!.containsKey('match') && _nextMatch!['match'] != null) {
        matchToShow = _nextMatch!['match'];
        hasClubMatch = true;
      }
    }
    
    // Similarly check for national team match
    bool hasNationalMatch = false;
    if (!hasClubMatch && _nationalTeamNextMatch != null) {
      // Match could be directly in _nationalTeamNextMatch
      if (_nationalTeamNextMatch!.containsKey('homeTeam') && _nationalTeamNextMatch!.containsKey('awayTeam')) {
        matchToShow = _nationalTeamNextMatch;
        hasNationalMatch = true;
        isNationalTeam = true;
      } 
      // Or inside a 'match' property
      else if (_nationalTeamNextMatch!.containsKey('match') && _nationalTeamNextMatch!['match'] != null) {
        matchToShow = _nationalTeamNextMatch!['match'];
        hasNationalMatch = true;
        isNationalTeam = true;
      }
    }
    
    // If we have multiple matches, prioritize based on date
    if (hasClubMatch && hasNationalMatch) {
      // Parse dates for both matches
      DateTime? clubMatchDateTime;
      DateTime? nationalMatchDateTime;
      
      try {
        // Try to parse date for club match
        if (matchToShow!.containsKey('utcDate')) {
          clubMatchDateTime = DateTime.parse(matchToShow['utcDate']);
        } else if (matchToShow!.containsKey('fixture') && 
                  matchToShow['fixture'] != null &&
                  matchToShow['fixture'].containsKey('date')) {
          clubMatchDateTime = DateTime.parse(matchToShow['fixture']['date']);
        }
        
        // Try to parse date for national team match
        if (_nationalTeamNextMatch!.containsKey('utcDate')) {
          nationalMatchDateTime = DateTime.parse(_nationalTeamNextMatch!['utcDate']);
        } else if (_nationalTeamNextMatch!.containsKey('match') && 
                  _nationalTeamNextMatch!['match'] != null &&
                  _nationalTeamNextMatch!['match'].containsKey('utcDate')) {
          nationalMatchDateTime = DateTime.parse(_nationalTeamNextMatch!['match']['utcDate']);
        } else if (_nationalTeamNextMatch!.containsKey('fixture') && 
                  _nationalTeamNextMatch!['fixture'] != null &&
                  _nationalTeamNextMatch!['fixture'].containsKey('date')) {
          nationalMatchDateTime = DateTime.parse(_nationalTeamNextMatch!['fixture']['date']);
        }
        
        // Choose the closest upcoming match
        if (clubMatchDateTime != null && nationalMatchDateTime != null) {
          if (clubMatchDateTime.isBefore(nationalMatchDateTime)) {
            // Keep club match (already selected)
            isNationalTeam = false;
          } else {
            // Use national team match
            matchToShow = _nationalTeamNextMatch!.containsKey('match') ? 
                          _nationalTeamNextMatch!['match'] : _nationalTeamNextMatch;
            isNationalTeam = true;
          }
        }
      } catch (e) {
        debugPrint('Error parsing match dates: $e');
        // Keep the default selection if date parsing fails
      }
    }
    
    // If we found a match to display, show it
    if (matchToShow != null) {
      debugPrint('Found match to show: ${matchToShow.keys.join(', ')}');
      return _buildMatchCard(matchToShow, isNationalTeam: isNationalTeam);
    }
    
    // If no match found, display a message
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Next Match',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No upcoming matches found',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map<String, dynamic>? matchData, {bool isNationalTeam = false}) {
    if (matchData == null) {
      // Return a fallback UI if matchData is null
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        height: 250,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Next Match',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Match data not available',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Print debug info to see the structure
    debugPrint('Building match card with data: ${matchData.keys.join(', ')}');
    
    // Extract data with appropriate null checks
    final Map<String, dynamic> competition = matchData['competition'] ?? {'name': 'Unknown'};
    final Map<String, dynamic> homeTeam = matchData['homeTeam'] ?? {'name': 'Home'};
    final Map<String, dynamic> awayTeam = matchData['awayTeam'] ?? {'name': 'Away'};
    
    // Extract logos with null checks
    final String? competitionLogo = competition['emblem'];
    final String? homeTeamLogo = homeTeam['crest'];
    final String? awayTeamLogo = awayTeam['crest'];
    
    // Extract match status
    final String matchStatus = matchData['status'] ?? '';
    
    // Parse match date with proper error handling
    DateTime matchDate;
    try {
      matchDate = DateTime.parse(matchData['utcDate'] ?? '');
    } catch (e) {
      debugPrint('Error parsing match date: $e');
      matchDate = DateTime.now().add(const Duration(days: 1));
    }
    
    // Format date
    final formattedDate = DateFormat('MMM d, yyyy').format(matchDate);
    final formattedTime = DateFormat('HH:mm').format(matchDate);
    
    // Get score information if available
    var homeScore, awayScore;
    
    // First check if there's a nested score structure
    if (matchData.containsKey('score') && matchData['score'] != null) {
      if (matchData['score'].containsKey('fullTime') && matchData['score']['fullTime'] != null) {
        homeScore = matchData['score']['fullTime']['home'];
        awayScore = matchData['score']['fullTime']['away'];
      }
    } else if (matchData.containsKey('goals') && matchData['goals'] != null) {
      // Alternative structure might use 'goals' property
      homeScore = matchData['goals']['home'];
      awayScore = matchData['goals']['away'];
    }
    
    final hasScore = homeScore != null && awayScore != null;
    final scoreText = hasScore ? '$homeScore - $awayScore' : 'vs';
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Next Match',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (competitionLogo != null && competitionLogo.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      _getProxiedImageUrl(competitionLogo),
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.emoji_events,
                        size: 24,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  competition['name'] ?? 'Unknown Competition',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    homeTeamLogo != null && homeTeamLogo.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _getProxiedImageUrl(homeTeamLogo),
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.sports_soccer, size: 32),
                              ),
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.sports_soccer, size: 32),
                          ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        homeTeam['name'] ?? 'Home Team',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Column(
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
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
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
                Column(
                  children: [
                    awayTeamLogo != null && awayTeamLogo.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _getProxiedImageUrl(awayTeamLogo),
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 64,
                                height: 64,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.sports_soccer, size: 32),
                              ),
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.sports_soccer, size: 32),
                          ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        awayTeam['name'] ?? 'Away Team',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    matchData['venue'] ?? 'Venue not available',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    // Create a ScrollController
    final ScrollController scrollController = ScrollController();
    
    // Calculate screen width to center selected date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        // Get the width of the ListView (minus the arrows)
        double viewportWidth = scrollController.position.viewportDimension;
        
        // Calculate the position of the selected item - accounting for varying widths
        double offset = 0;
        for (int i = 0; i < _currentDateIndex; i++) {
          // Check if this date is Yesterday or Tomorrow
          final DateTime date = _dateRange[i];
          final bool isTomorrow = _isTomorrow(date);
          final bool isYesterday = _isYesterday(date);
          
          // Use wider box for Yesterday/Tomorrow
          offset += (isTomorrow || isYesterday) ? 100.0 : 80.0;
        }
        
        // Add half the width of the selected item
        final bool isSelectedTomorrowOrYesterday = 
            _isTomorrow(_dateRange[_currentDateIndex]) || 
            _isYesterday(_dateRange[_currentDateIndex]);
        offset += isSelectedTomorrowOrYesterday ? 50.0 : 40.0;
        
        // Center the selected item
        offset -= viewportWidth / 2;
        
        // Ensure the offset is within bounds
        offset = offset.clamp(0.0, scrollController.position.maxScrollExtent);
        
        // Scroll to the calculated offset
        scrollController.jumpTo(offset);
      }
    });
    
    return SizedBox(
      height: 70, // Reduce height since we removed day of week
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => _changeDate(-1),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _dateRange.length,
              controller: scrollController,
              cacheExtent: 2000, // Ensure all items can be cached
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final date = _dateRange[index];
                final isSelected = index == _currentDateIndex;
                final isToday = _isToday(date);
                final isTomorrow = _isTomorrow(date);
                final isYesterday = _isYesterday(date);
                
                // Make Yesterday and Tomorrow boxes slightly wider
                final double buttonWidth = (isYesterday || isTomorrow) ? 92.0 : 72.0;
                
                return InkWell(
                  onTap: () => _selectDate(date, index),
                  child: Container(
                    width: buttonWidth,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFE6AC) : Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              isToday 
                                  ? AppLocalizations.of(context)?.today ?? 'Today'
                                  : isTomorrow
                                      ? AppLocalizations.of(context)?.tomorrow ?? 'Tomorrow'
                                      : isYesterday
                                          ? AppLocalizations.of(context)?.yesterday ?? 'Yesterday'
                                          : DateFormat('MMM').format(date),
                              style: TextStyle(
                                color: isSelected ? Colors.black : isToday ? const Color(0xFFFFE6AC) : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            child: Text(
                              DateFormat('d').format(date),
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    final now = _currentDate;
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  bool _isTomorrow(DateTime date) {
    final tomorrow = _currentDate.add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }
  
  bool _isYesterday(DateTime date) {
    final yesterday = _currentDate.subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }
  
  Widget _buildMatchesForDay() {
    final Widget content;
    
    if (_matchesByDay.isEmpty) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sports_soccer,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)?.noMatchesScheduled ?? 'No matches scheduled for this day',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Group matches by competition
      Map<String, List<dynamic>> matchesByCompetition = {};
      for (var match in _matchesByDay) {
        final competitionName = match['competition']['name'];
        if (!matchesByCompetition.containsKey(competitionName)) {
          matchesByCompetition[competitionName] = [];
        }
        matchesByCompetition[competitionName]!.add(match);
      }
      
      content = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: matchesByCompetition.length,
        itemBuilder: (context, index) {
          final competitionName = matchesByCompetition.keys.elementAt(index);
          final matches = matchesByCompetition[competitionName]!;
          final competition = matches.first['competition'];
          final String? competitionLogo = competition['emblem'];
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    if (competitionLogo != null && competitionLogo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            _getProxiedImageUrl(competitionLogo),
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => 
                              const SizedBox(width: 24),
                          ),
                        ),
                      ),
                    Text(
                      competitionName,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              ...matches.map((match) => _buildMatchItem(match)),
              const SizedBox(height: 16),
            ],
          );
        },
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      margin: const EdgeInsets.only(
        top: 16.0,
        bottom: 120.0, // Increased from 72 to 120 to prevent overflow
        left: 16.0,
        right: 16.0,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6, // Keep max height at 60% of screen height
          minHeight: _matchesByDay.isEmpty ? 200 : 100, // Minimum height to ensure visibility
        ),
        child: content,
      ),
    );
  }

  Widget _buildMatchItem(dynamic match) {
    final homeTeam = match['homeTeam'];
    final awayTeam = match['awayTeam'];
    final String? homeTeamLogo = homeTeam['crest'];
    final String? awayTeamLogo = awayTeam['crest'];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Parse match date
    DateTime matchDate;
    try {
      matchDate = DateTime.parse(match['utcDate']);
    } catch (e) {
      matchDate = DateTime.now();
    }
    
    final formattedTime = DateFormat('HH:mm').format(matchDate);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      color: isDarkMode ? const Color(0xFF292929) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Match time
            SizedBox(
              width: 50,
              child: Text(
                formattedTime,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Home team
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () => _navigateToTeamDetails(
                        homeTeam['id'].toString(), 
                        homeTeam['name']
                      ),
                      child: Text(
                        homeTeam['name'],
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (homeTeamLogo != null && homeTeamLogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          _getProxiedImageUrl(homeTeamLogo),
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => 
                            const SizedBox(width: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Score separator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                AppLocalizations.of(context)?.versus ?? 'vs',
                style: TextStyle(
                  color: const Color(0xFFFFE6AC),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            // Away team
            Expanded(
              child: Row(
                children: [
                  if (awayTeamLogo != null && awayTeamLogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          _getProxiedImageUrl(awayTeamLogo),
                          width: 20,
                          height: 20,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => 
                            const SizedBox(width: 20),
                        ),
                      ),
                    ),
                  Flexible(
                    child: InkWell(
                      onTap: () => _navigateToTeamDetails(
                        awayTeam['id'].toString(), 
                        awayTeam['name']
                      ),
                      child: Text(
                        awayTeam['name'],
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add a helper method for the next match skeleton
  Widget _buildNextMatchContentSkeleton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Next Match',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 60,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 50,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 180,
                height: 14,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 