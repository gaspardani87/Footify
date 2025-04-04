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

// Animated List Item Wrapper
class _AnimatedListItemWrapper extends StatefulWidget {
  final Widget child;
  final int index;
  final bool isVisible;
  final Duration delayDuration;
  final Duration animationDuration;

  const _AnimatedListItemWrapper({
    required Key key, // Ensure key is passed
    required this.child,
    required this.index,
    required this.isVisible,
    required this.delayDuration,
    this.animationDuration = const Duration(milliseconds: 250), // Duration for the item's own animation
  }) : super(key: key);

  @override
  __AnimatedListItemWrapperState createState() => __AnimatedListItemWrapperState();
}

class __AnimatedListItemWrapperState extends State<_AnimatedListItemWrapper> {
  bool _isActuallyVisible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // If initially visible (e.g., starts expanded), trigger animation immediately
    // The delay is handled by the _scheduleAnimation method
    if (widget.isVisible) {
      _scheduleAnimation();
    } else {
        // Ensure it's hidden if starting collapsed
        _isActuallyVisible = false;
    }
  }

  @override
  void didUpdateWidget(_AnimatedListItemWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        // Becoming visible: schedule animation if not already running/visible
        _scheduleAnimation();
      } else {
        // Becoming hidden: cancel timer and hide immediately
        _timer?.cancel();
        // Check if widget is still in the tree before calling setState
        if (mounted) {
             setState(() {
                _isActuallyVisible = false;
             });
        }
      }
    }
  }

  void _scheduleAnimation() {
    // Cancel any existing timer
    _timer?.cancel();
    // Don't restart if already visible or widget unmounted
    if (_isActuallyVisible || !mounted) return;

    // Calculate the actual delay for this specific item
    final delay = widget.delayDuration * widget.index;
    _timer = Timer(delay, () {
       // Check again if it should be visible and mounted when timer fires
       if (mounted && widget.isVisible) {
          setState(() {
            _isActuallyVisible = true;
          });
       }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use AnimatedOpacity and AnimatedSlide controlled by the internal state
    return AnimatedOpacity(
      opacity: _isActuallyVisible ? 1.0 : 0.0,
      duration: widget.animationDuration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _isActuallyVisible ? Offset.zero : const Offset(0.0, 0.3), // Slide from bottom
        duration: widget.animationDuration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
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
  
  // Competition expansion state
  final Map<String, bool> _expandedCompetitions = {};
  
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
        // If no matches are cached for the day, try loading them (might be needed if cache expired)
        _loadMatchesForDay(formattedDate);
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
      physics: const AlwaysScrollableScrollPhysics(),
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
                  AppLocalizations.of(context)?.upcomingMatches ?? 'Matches',
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
    final String favoriteTeamNameFromUser = userData['favoriteTeam'] ?? '';
    final String favoriteTeamId = userData['favoriteTeamId'] ?? '';
    
    // Try to find the favorite team's data in the league standings
    Map<String, dynamic>? favoriteTeamDataFromStandings;
    String? teamLogo;
    if (_leagueStandings != null && favoriteTeamId.isNotEmpty) {
      final standings = _leagueStandings?['standings']?[0]?['table'] ?? [];
      for (var teamEntry in standings) {
        if (teamEntry['team']?['id']?.toString() == favoriteTeamId) {
          favoriteTeamDataFromStandings = teamEntry['team'];
          teamLogo = favoriteTeamDataFromStandings?['crest'];
          break;
        }
      }
    }

    // Determine the name to display: short name from standings if available, else full name from user data
    final String teamNameToDisplay = favoriteTeamDataFromStandings != null
        ? _getShortTeamName(favoriteTeamDataFromStandings)
        : favoriteTeamNameFromUser;
    
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        // ADD SHADOW
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: favoriteTeamId.isNotEmpty 
            ? () => _navigateToTeamDetails(favoriteTeamId, teamNameToDisplay)
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
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFE6AC) : Colors.black87,
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
                      child: teamNameToDisplay.isNotEmpty
                        ? Text( // Directly use Text with the determined name
                            teamNameToDisplay,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2, // Allow wrapping up to 2 lines
                            overflow: TextOverflow.ellipsis, // Add ellipsis if it exceeds 2 lines
                          )
                        : Text(
                            AppLocalizations.of(context)?.noTeamSelected ?? 'No team selected',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
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

  // Helper function to get short team name (shortName > name)
  String _getShortTeamName(Map<String, dynamic>? teamData) {
    if (teamData == null) return '?';
    return teamData['shortName']?.isNotEmpty == true 
           ? teamData['shortName'] 
           : teamData['name'] ?? '?';
  }

  // Helper function to get responsive team name (tla > shortName > name on small screens)
  String _getResponsiveTeamName(Map<String, dynamic>? teamData, BuildContext context) {
    if (teamData == null) return '?';
    final screenWidth = MediaQuery.of(context).size.width;
    final String name = teamData['name'] ?? '?';
    final String? shortName = teamData['shortName'];
    final String? tla = teamData['tla'];

    if (screenWidth < 600) { // Threshold for mobile/small screens
      return tla?.isNotEmpty == true 
             ? tla! 
             : shortName?.isNotEmpty == true 
               ? shortName! 
               : name;
    } else { // Larger screens
      return shortName?.isNotEmpty == true 
             ? shortName! 
             : name;
    }
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
        // ADD SHADOW
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
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
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFFE6AC) : Colors.black87,
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
                        ? Text( // Use a simple Text widget for the nation name
                            favoriteNation,
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2, // Allow wrapping up to 2 lines
                            overflow: TextOverflow.ellipsis, // Add ellipsis if it exceeds 2 lines
                          )
                        : Text(
                            AppLocalizations.of(context)?.noNationSelected ?? 'No nation selected',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
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
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
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
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
        // ADD SHADOW
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          ),
        ],
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
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
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
            // final teamName = team['team']['name']; // Use helper instead
            final teamMap = team['team']; // Get the full team map
            final teamNameToDisplay = _getShortTeamName(teamMap); // Use helper
            final teamId = team['team']['id'].toString();
            final teamCrest = team['team']['crest'];
            final playedGames = team['playedGames'];
            final won = team['won'];
            final draw = team['draw'];
            final lost = team['lost'];
            final points = team['points'];
            
            final bool isFavorite = teamId == favoriteTeamId;
            
            return InkWell(
              onTap: () => _navigateToTeamDetails(teamId, teamNameToDisplay),
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
                              teamNameToDisplay,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
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
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
    
    // ---> NEW LOGIC: Prioritize Live Match <----
    Map<String, dynamic>? matchToShow;
    bool isNationalTeam = false;
    
    // 1. Check for ongoing match today
    final String? favoriteTeamId = userData?['favoriteTeamId'];
    final String? favoriteNationalTeamId = userData?['favoriteNationalTeamId'];
    final todayFormatted = _formatDate(_currentDate);
    final todaysMatches = _matchesCache[todayFormatted] ?? [];
    Map<String, dynamic>? liveMatchToShow;
    bool liveMatchIsNational = false;

    if (favoriteTeamId != null || favoriteNationalTeamId != null) {
      for (var match in todaysMatches) {
        final status = match['status']?.toString().toUpperCase();
        final homeId = match['homeTeam']?['id']?.toString();
        final awayId = match['awayTeam']?['id']?.toString();

        bool isFavClubMatch = (favoriteTeamId != null && (homeId == favoriteTeamId || awayId == favoriteTeamId));
        bool isFavNationMatch = (favoriteNationalTeamId != null && (homeId == favoriteNationalTeamId || awayId == favoriteNationalTeamId));

        if (isFavClubMatch || isFavNationMatch) {
          if (status == 'IN_PLAY' || status == 'LIVE' || status == 'PAUSED' || status == 'HALF_TIME') {
            liveMatchToShow = match;
            liveMatchIsNational = isFavNationMatch; // Mark if it's the national team
            debugPrint('Found live match to prioritize: ${liveMatchToShow?['id']}');
            break; // Found a live match, no need to check further
          }
        }
      }
    }

    // 2. Decide which match to show
    if (liveMatchToShow != null) {
      // Prioritize the live match found today
      matchToShow = liveMatchToShow;
      isNationalTeam = liveMatchIsNational;
    } else {
      // No live match today, use existing logic for next scheduled match
      bool hasClubMatch = false;
      Map<String, dynamic>? scheduledClubMatchData;
      if (_nextMatch != null) {
        if (_nextMatch!.containsKey('homeTeam') && _nextMatch!.containsKey('awayTeam')) {
          scheduledClubMatchData = _nextMatch;
          hasClubMatch = true;
        } else if (_nextMatch!.containsKey('match') && _nextMatch!['match'] != null) {
          scheduledClubMatchData = _nextMatch!['match'];
          hasClubMatch = true;
        }
      }
      
      bool hasNationalMatch = false;
      Map<String, dynamic>? scheduledNationalMatchData;
      if (_nationalTeamNextMatch != null) {
        if (_nationalTeamNextMatch!.containsKey('homeTeam') && _nationalTeamNextMatch!.containsKey('awayTeam')) {
          scheduledNationalMatchData = _nationalTeamNextMatch;
          hasNationalMatch = true;
        } else if (_nationalTeamNextMatch!.containsKey('match') && _nationalTeamNextMatch!['match'] != null) {
          scheduledNationalMatchData = _nationalTeamNextMatch!['match'];
          hasNationalMatch = true;
        }
      }
      
      // Choose which scheduled match is sooner
      if (hasClubMatch && hasNationalMatch) {
        DateTime? clubMatchDateTime;
        DateTime? nationalMatchDateTime;
        try {
          // Parse club match date
          if (scheduledClubMatchData!.containsKey('utcDate')) {
            clubMatchDateTime = DateTime.parse(scheduledClubMatchData['utcDate']);
          } // Add other potential date fields if necessary
          
          // Parse national match date
          if (scheduledNationalMatchData!.containsKey('utcDate')) {
            nationalMatchDateTime = DateTime.parse(scheduledNationalMatchData['utcDate']);
          } // Add other potential date fields if necessary
          
          if (clubMatchDateTime != null && nationalMatchDateTime != null) {
            if (clubMatchDateTime.isBefore(nationalMatchDateTime)) {
              matchToShow = scheduledClubMatchData;
              isNationalTeam = false;
            } else {
              matchToShow = scheduledNationalMatchData;
              isNationalTeam = true;
            }
          } else if (clubMatchDateTime != null) {
            matchToShow = scheduledClubMatchData;
            isNationalTeam = false;
          } else if (nationalMatchDateTime != null) {
            matchToShow = scheduledNationalMatchData;
            isNationalTeam = true;
          }
        } catch (e) {
          debugPrint('Error parsing scheduled match dates: $e');
          // Fallback if parsing fails, maybe default to club match if available
          if (hasClubMatch) {
             matchToShow = scheduledClubMatchData;
             isNationalTeam = false;
          } else if (hasNationalMatch) {
             matchToShow = scheduledNationalMatchData;
             isNationalTeam = true;
          }
        }
      } else if (hasClubMatch) {
        matchToShow = scheduledClubMatchData;
        isNationalTeam = false;
      } else if (hasNationalMatch) {
        matchToShow = scheduledNationalMatchData;
        isNationalTeam = true;
      }
    }

    // ----> END OF NEW LOGIC <----
    
    /* ---- Commented out old logic ----
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
    if (_nationalTeamNextMatch != null) { // Changed from: if (!hasClubMatch && _nationalTeamNextMatch != null)
      // Match could be directly in _nationalTeamNextMatch
      if (_nationalTeamNextMatch!.containsKey('homeTeam') && _nationalTeamNextMatch!.containsKey('awayTeam')) {
        // Only assign if matchToShow is still null
        if (matchToShow == null) { 
            matchToShow = _nationalTeamNextMatch;
            isNationalTeam = true; 
        }
        hasNationalMatch = true; // Mark that a national match exists
      } 
      // Or inside a 'match' property
      else if (_nationalTeamNextMatch!.containsKey('match') && _nationalTeamNextMatch!['match'] != null) {
         // Only assign if matchToShow is still null
        if (matchToShow == null) { 
            matchToShow = _nationalTeamNextMatch!['match'];
            isNationalTeam = true;
        }
        hasNationalMatch = true; // Mark that a national match exists
      }
    }
    
    // If we have multiple matches, prioritize based on date
    if (hasClubMatch && hasNationalMatch) {
      // Parse dates for both matches
      DateTime? clubMatchDateTime;
      DateTime? nationalMatchDateTime;
      Map<String, dynamic>? clubMatchData = _nextMatch?.containsKey('match') ?? false 
                                          ? _nextMatch!['match'] 
                                          : _nextMatch;
      Map<String, dynamic>? nationalMatchData = _nationalTeamNextMatch?.containsKey('match') ?? false
                                              ? _nationalTeamNextMatch!['match']
                                              : _nationalTeamNextMatch;

      try {
        // Try to parse date for club match
        if (clubMatchData != null && clubMatchData.containsKey('utcDate')) {
          clubMatchDateTime = DateTime.parse(clubMatchData['utcDate']);
        } // Add other potential date fields if necessary
        
        // Try to parse date for national team match
        if (nationalMatchData != null && nationalMatchData.containsKey('utcDate')) {
          nationalMatchDateTime = DateTime.parse(nationalMatchData['utcDate']);
        } // Add other potential date fields if necessary
        
        // Choose the closest upcoming match
        if (clubMatchDateTime != null && nationalMatchDateTime != null) {
          if (clubMatchDateTime.isBefore(nationalMatchDateTime)) {
            matchToShow = clubMatchData;
            isNationalTeam = false;
          } else {
            matchToShow = nationalMatchData;
            isNationalTeam = true;
          }
        }
      } catch (e) {
        debugPrint('Error parsing match dates: $e');
        // Keep the default selection if date parsing fails
      }
    }
    */

    // If we found a match to display (either live or scheduled), show it
    if (matchToShow != null) {
      debugPrint('Found match to show: ${matchToShow.keys.join(', ')}');
      return _buildMatchCard(matchToShow, isNationalTeam: isNationalTeam);
    }
    
    // If no match found, display a message
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
              AppLocalizations.of(context)?.nextMatch ?? 'Next Match',
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
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        height: 270, // Reduced from 300, original was 250
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
              padding: const EdgeInsets.all(14.0), // Reduced from 16.0
              child: Text(
                AppLocalizations.of(context)?.nextMatch ?? 'Next Match',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0), // Reduced from 24.0
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
    final Map<String, dynamic> homeTeam = matchData['homeTeam'] ?? {'name': 'Home', 'shortName': 'Home'};
    final Map<String, dynamic> awayTeam = matchData['awayTeam'] ?? {'name': 'Away', 'shortName': 'Away'};
    
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
      margin: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white,
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
            padding: const EdgeInsets.all(16.0), // Reduced from 20.0
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.nextMatch ?? 'Next Match',
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
                const SizedBox(width: 10), // Reduced from 12
                Text(
                  competition['name'] ?? 'Unknown Competition',
                  style: TextStyle(
                    color: const Color(0xFFFFE6AC),
                    fontSize: 14,
                    fontWeight: FontWeight.bold, // Add this line
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0), // Reduced from 24.0, 16.0
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
                              width: 70, // Reduced from 80, original was 64
                              height: 70, // Reduced from 80, original was 64
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 70,
                                height: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.sports_soccer, size: 35), // Reduced from 40
                              ),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.sports_soccer, size: 35),
                          ),
                    const SizedBox(height: 12), // Reduced from 16
                    SizedBox(
                      width: 110, // Reduced from 120
                      child: Text(
                        _getShortTeamName(homeTeam),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15, // Reduced from 16
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12), // Reduced from 16
                  ],
                ),
                Column(
                  children: [
                    _buildMatchCardStatus(matchData),
                    const SizedBox(height: 12), // Reduced from 16
                    _buildMatchCardDateTime(matchData, isDarkMode),
                  ],
                ),
                Column(
                  children: [
                    awayTeamLogo != null && awayTeamLogo.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _getProxiedImageUrl(awayTeamLogo),
                              width: 70,
                              height: 70,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 70,
                                height: 70,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.sports_soccer, size: 35),
                              ),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.sports_soccer, size: 35),
                          ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 110,
                      child: Text(
                        _getShortTeamName(awayTeam),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16
        ],
      ),
    );
  }

  // Helper for Match Card: Status/Score Display
  Widget _buildMatchCardStatus(Map<String, dynamic> matchData) {
    final matchStatus = matchData['status']?.toString().toUpperCase();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Score
    var homeScore, awayScore;
    if (matchData.containsKey('score') && matchData['score'] != null &&
        matchData['score'].containsKey('fullTime') && matchData['score']['fullTime'] != null) {
      homeScore = matchData['score']['fullTime']['home'];
      awayScore = matchData['score']['fullTime']['away'];
    }
    final bool hasScore = homeScore != null && awayScore != null;

    switch (matchStatus) {
      case 'IN_PLAY':
      case 'LIVE':
        // --- REVERTED: Use BlinkingLiveIndicator --- 
        return Column(
          children: [
            // --- REVERTED: Use BlinkingLiveIndicator --- 
            const _BlinkingLiveIndicator(), 
            const SizedBox(height: 4),
            Text(
                hasScore ? '$homeScore - $awayScore' : '- : -', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
             ),
          ],
        );
      case 'PAUSED':
      case 'HALF_TIME':
        return Column(
          children: [
             Text(
                AppLocalizations.of(context)?.halfTimeStatus ?? 'HT',
                style: TextStyle(color: isDarkMode ? Colors.yellow : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
             ),
             const SizedBox(height: 4),
             Text(
                hasScore ? '$homeScore - $awayScore' : '- : -', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
             ),
          ],
        );
      case 'FINISHED':
      case 'FT':
         return Column(
          children: [
             Text(
                AppLocalizations.of(context)?.fullTimeStatus ?? 'FT',
                style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
             ),
             const SizedBox(height: 4),
             Text(
                hasScore ? '$homeScore - $awayScore' : '- : -', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
             ),
          ],
        );
      default: // SCHEDULED, TIMED, POSTPONED, etc.
        return Container(
           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          child: Text(
            AppLocalizations.of(context)?.versus ?? 'vs',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        );
    }
  }

  // Helper for Match Card: Date/Time Display
  Widget _buildMatchCardDateTime(Map<String, dynamic> matchData, bool isDarkMode) {
     final matchStatus = matchData['status']?.toString().toUpperCase();
     DateTime matchDate;
     try {
        matchDate = DateTime.parse(matchData['utcDate'] ?? '');
      } catch (e) {
        return const SizedBox.shrink(); // Don't show if date invalid
      }
      final formattedDate = DateFormat('MMM d, yyyy').format(matchDate);
      final formattedTime = DateFormat('HH:mm').format(matchDate);

      TextStyle defaultStyle = TextStyle(
        color: isDarkMode ? Colors.white70 : Colors.black54,
        fontSize: 12,
      );
      TextStyle boldStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);

      // Show date/time only for scheduled/default cases
      switch(matchStatus) {
        case 'TIMED':
        case 'SCHEDULED':
          return Column(
             children: [
               Text(formattedDate, style: defaultStyle),
               Text(formattedTime, style: boldStyle),
             ],
          );
        case 'POSTPONED':
           return Text(
              AppLocalizations.of(context)?.postponedStatus ?? 'PST',
              style: TextStyle(color: Colors.grey, fontSize: 12)
           );
        case 'SUSPENDED':
           return Text(
              AppLocalizations.of(context)?.suspendedStatus ?? 'SUS',
              style: TextStyle(color: Colors.orange, fontSize: 12)
           );
        case 'CANCELLED':
           return Text(
              AppLocalizations.of(context)?.cancelledStatus ?? 'CAN',
              style: TextStyle(color: Colors.red, fontSize: 12)
           );
        default: // Hide date/time for ongoing/finished matches
          return const SizedBox.shrink();
      }
  }

  Widget _buildDateSelector() {
    // Create a ScrollController
    final ScrollController scrollController = ScrollController();
    // ADD: Get dark mode status
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
                      // UPDATE COLOR LOGIC FOR BETTER DARK MODE VISIBILITY
                      color: isSelected
                        ? const Color(0xFFFFE6AC) // Selected color is gold
                        : isDarkMode
                          ? Colors.grey[850] // Unselected dark: Slightly lighter grey
                          : Colors.white,   // Unselected light: White
                      borderRadius: BorderRadius.circular(16),
                      // APPLY BORDER TO UNSELECTED CARDS IN BOTH MODES
                      border: !isSelected 
                        ? Border.all(
                            color: isDarkMode 
                                ? Colors.white.withOpacity(0.15) // Dark mode border
                                : Colors.black.withOpacity(0.1), // Light mode border
                            width: 1,
                          )
                        : null, // No border for selected card
                      boxShadow: [ // Keep consistent shadow for all cards
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4.0,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                                // UPDATE TEXT COLOR LOGIC FOR LIGHT MODE VISIBILITY
                                color: isSelected
                                    ? Colors.black // Selected card text is always black
                                    : isDarkMode
                                        ? (isToday ? const Color(0xFFFFE6AC) : Colors.white) // Dark mode: Today is gold, others are white
                                        : Colors.black, // Light mode: Unselected text is black
                                fontWeight: FontWeight.bold,
                                fontSize: 14, // Correct font size for month/day name
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 30,
                            child: Text(
                              DateFormat('d').format(date),
                              style: TextStyle(
                                // CORRECTED TEXT COLOR LOGIC
                                color: isSelected
                                    ? Colors.black // Selected card text is always black
                                    : isDarkMode
                                        ? Colors.white // Dark mode: Unselected day number is white
                                        : Colors.black, // Light mode: Unselected day number is black
                                fontWeight: FontWeight.bold,
                                fontSize: 20, // Correct font size for day number
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
      
      content = Column(
        children: matchesByCompetition.entries.map((entry) {
          final competitionName = entry.key;
          final matches = entry.value;
          
          // Kinyerjük a bajnokság emblémáját és ID-jét az első mérkőzés adataiból
          final competitionEmblem = matches.isNotEmpty ? matches[0]['competition']['emblem'] : null;
          final competitionId = matches.isNotEmpty ? matches[0]['competition']['id'] : null;
          
          return StatefulBuilder(
            builder: (context, setState) {
              // Ensure a default value if the key doesn't exist yet
              _expandedCompetitions.putIfAbsent(competitionName, () => true);
              final bool isExpanded = _expandedCompetitions[competitionName]!;

              return Card(
                margin: const EdgeInsets.only(bottom: 20, left: 8, right: 8),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.2), // ADD SHADOW COLOR
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _expandedCompetitions[competitionName] = !isExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(top: 4.0),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF292929),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isExpanded ? Radius.zero : const Radius.circular(12),
                            bottomRight: isExpanded ? Radius.zero : const Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                             if (competitionEmblem != null && competitionEmblem.isNotEmpty)
                               Padding(
                                 padding: const EdgeInsets.only(right: 8.0),
                                 child: ClipRRect(
                                   borderRadius: BorderRadius.circular(4),
                                   child: _buildLogoImage(
                                     competitionId ?? 0,
                                     competitionEmblem,
                                     Theme.of(context).brightness == Brightness.dark,
                                     kIsWeb,
                                   ),
                                 ),
                               ),
                            Expanded(
                              child: Text(
                                competitionName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 300),
                              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Use AnimatedSize for smoother transitions of the container height
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      // Use ClipRect to prevent children overflowing during animation
                      child: ClipRect(
                        child: isExpanded
                            ? Column( // Keep the Column
                                children: matches.asMap().entries.map((entry) { // Use asMap().entries to get index
                                  int index = entry.key;
                                  var match = entry.value;
                                  // Wrap each item with the animation wrapper
                                  return _AnimatedListItemWrapper(
                                    // Use a unique and stable key for each item
                                    key: ValueKey(match['id'] ?? 'match_$index'),
                                    index: index,
                                    isVisible: isExpanded, // Pass the expansion state
                                    delayDuration: const Duration(milliseconds: 50), // Stagger delay
                                    child: _buildMatchItem(match),
                                  );
                                }).toList(),
                              )
                            : const SizedBox.shrink(), // Collapse the content when not expanded
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }).toList(),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(
        top: 16.0,
        bottom: 16.0,
        left: 0.0,
        right: 0.0,
      ),
      child: content,
    );
  }

  Widget _buildMatchItem(dynamic match) {
    final homeTeam = match['homeTeam'];
    final awayTeam = match['awayTeam'];
    final String? homeTeamLogo = homeTeam['crest'];
    final String? awayTeamLogo = awayTeam['crest'];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final matchStatus = match['status']?.toString().toUpperCase();

    // Parse match date
    DateTime matchDate;
    try {
      matchDate = DateTime.parse(match['utcDate']);
    } catch (e) {
      matchDate = DateTime.now();
    }
    final formattedTime = DateFormat('HH:mm').format(matchDate);

    // Get score information if available
    var homeScore, awayScore;
    if (match.containsKey('score') && match['score'] != null &&
        match['score'].containsKey('fullTime') && match['score']['fullTime'] != null) {
      homeScore = match['score']['fullTime']['home'];
      awayScore = match['score']['fullTime']['away'];
    }
    final bool hasScore = homeScore != null && awayScore != null;

    Widget statusOrTimeWidget;
    Widget scoreOrVsWidget;

    switch (matchStatus) {
      case 'IN_PLAY':
      case 'LIVE': // Some APIs might use LIVE
        // --- REVERTED: Use BlinkingLiveIndicator --- 
        statusOrTimeWidget = const _BlinkingLiveIndicator(); 
        scoreOrVsWidget = Text(
          hasScore ? '$homeScore - $awayScore' : '- : -', // Show placeholder if score not yet available
          style: TextStyle(
            color: const Color(0xFFFFE6AC),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );
        break;
      case 'PAUSED': // Half Time often uses PAUSED
      case 'HALF_TIME':
        statusOrTimeWidget = Text(
          AppLocalizations.of(context)?.halfTimeStatus ?? 'HT', // Use default string
          style: TextStyle(
            color: isDarkMode ? Colors.yellow : Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
        scoreOrVsWidget = Text(
          hasScore ? '$homeScore - $awayScore' : '- : -',
          style: TextStyle(
            color: const Color(0xFFFFE6AC),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );
        break;
      case 'FINISHED':
      case 'FT': // Some APIs might use FT explicitly
        statusOrTimeWidget = Text(
          AppLocalizations.of(context)?.fullTimeStatus ?? 'FT', // Use default string
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        );
         scoreOrVsWidget = Text(
          hasScore ? '$homeScore - $awayScore' : '- : -', // Should always have score at FT
          style: TextStyle(
            color: const Color(0xFFFFE6AC),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );
        break;
      case 'TIMED':
      case 'SCHEDULED':
      case 'POSTPONED':
      case 'SUSPENDED':
      case 'CANCELLED':
      default: // Includes TIMED, SCHEDULED, POSTPONED etc.
        statusOrTimeWidget = Text(
          formattedTime,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        );
        scoreOrVsWidget = Text(
          AppLocalizations.of(context)?.versus ?? 'vs',
          style: TextStyle(
            color: const Color(0xFFFFE6AC),
            fontWeight: FontWeight.bold,
          ),
        );
        break;
    }

    // Handle POSTPONED, SUSPENDED, CANCELLED specifically in time/status display
    if (matchStatus == 'POSTPONED') {
       statusOrTimeWidget = Text(
        AppLocalizations.of(context)?.postponedStatus ?? 'PST', // Use default string
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    } else if (matchStatus == 'SUSPENDED') {
        statusOrTimeWidget = Text(
        AppLocalizations.of(context)?.suspendedStatus ?? 'SUS', // Use default string
        style: TextStyle(color: Colors.orange, fontSize: 12),
      );
    } else if (matchStatus == 'CANCELLED') {
       statusOrTimeWidget = Text(
        AppLocalizations.of(context)?.cancelledStatus ?? 'CAN', // Use default string
        style: TextStyle(color: Colors.red, fontSize: 12),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      color: isDarkMode ? const Color(0xFF292929) : Colors.white,
      elevation: 2, // ADD ELEVATION
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Match time or status indicator
            SizedBox(
              width: 50,
              child: Center(child: statusOrTimeWidget), // Center the status/time
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
                        homeTeam['name'] // Keep full name for navigation context if needed
                      ),
                      child: Text(
                        _getResponsiveTeamName(homeTeam, context), // Use responsive helper
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

            // Score or vs separator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: scoreOrVsWidget, // Use the dynamic widget here
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
                        awayTeam['name'] // Keep full name for navigation context if needed
                      ),
                      child: Text(
                        _getResponsiveTeamName(awayTeam, context), // Use responsive helper
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
                  AppLocalizations.of(context)?.nextMatch ?? 'Next Match',
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

  // Add logo handling logic from leagues.dart
  Widget _buildLogoImage(int leagueId, String? logoUrl, bool isDarkMode, bool isWeb) {
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
    };
    
    // Proxy használata a webes verzióban, minőségi paraméterrel
    String getProxiedUrl(String url) {
      if (kIsWeb) {
        // Ha SVG formátumú a kép, közvetlenül használjuk
        if (url.toLowerCase().endsWith('.svg') || url.toLowerCase().contains('.svg')) {
          return url;
        }
        return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(url)}';
      }
      return url;
    }

    // A problémás ligák világos módban sötét verziójú képet használnak
    if (!isDarkMode && darkVersionLogos.containsKey(leagueId)) {
      return Image.network(
        getProxiedUrl(darkVersionLogos[leagueId]!),
        fit: BoxFit.contain,
        width: 24,
        height: 24,
        headers: kIsWeb ? {'Origin': 'null'} : null,
        errorBuilder: (context, error, stackTrace) {
          print("Sötét verzió betöltési hiba (ID: $leagueId): $error");
          return Icon(
            Icons.sports_soccer, 
            size: 24,
            color: Colors.black54,
          );
        },
      );
    }
    
    // A problémás ligák sötét módban világos/fehér verziójú képet használnak
    if (isDarkMode && lightVersionLogos.containsKey(leagueId)) {
      return Image.network(
        getProxiedUrl(lightVersionLogos[leagueId]!),
        fit: BoxFit.contain,
        width: 24,
        height: 24,
        headers: kIsWeb ? {'Origin': 'null'} : null,
        errorBuilder: (context, error, stackTrace) {
          print("Világos verzió betöltési hiba (ID: $leagueId): $error");
          return Icon(
            Icons.sports_soccer, 
            size: 24,
            color: Colors.white70,
          );
        },
      );
    }
    
    // Eredivisie esetén fehérre színezzük sötét módban
    if (leagueId == 2003 && isDarkMode && replacementLogos.containsKey(leagueId)) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
        child: Image.network(
          getProxiedUrl(replacementLogos[leagueId]!),
          fit: BoxFit.contain,
          width: 24,
          height: 24,
          headers: kIsWeb ? {'Origin': 'null'} : null,
          errorBuilder: (context, error, stackTrace) {
            print("Helyettesítő kép betöltési hiba (ID: $leagueId): $error");
            return Icon(
              Icons.sports_soccer, 
              size: 24,
              color: Colors.white70,
            );
          },
        ),
      );
    }
    
    // Premier League és Bajnokok Ligája esetén fehér szín sötét módban - csak a Champions League esetén használjuk
    if (leagueId == 2001 && isDarkMode) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
        child: Image.network(
          getProxiedUrl(logoUrl ?? replacementLogos[leagueId]!),
          fit: BoxFit.contain,
          width: 24,
          height: 24,
          headers: kIsWeb ? {'Origin': 'null'} : null,
          errorBuilder: (context, error, stackTrace) {
            print("Fehérre színezett logó betöltési hiba (ID: $leagueId): $error");
            return Icon(
              Icons.sports_soccer, 
              size: 24,
              color: Colors.white70,
            );
          },
        ),
      );
    }
    
    // Ellenőrizzük, hogy van-e helyettesítő online kép
    if (replacementLogos.containsKey(leagueId)) {
      return Image.network(
        getProxiedUrl(replacementLogos[leagueId]!),
        fit: BoxFit.contain,
        width: 24,
        height: 24,
        headers: kIsWeb ? {'Origin': 'null'} : null,
        errorBuilder: (context, error, stackTrace) {
          print("Helyettesítő kép betöltési hiba (ID: $leagueId): $error");
          return Icon(
            Icons.sports_soccer, 
            size: 24,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          );
        },
      );
    }
    
    // Minden más esetben az eredeti logót használjuk
    return _getNetworkImage(logoUrl, isDarkMode, isWeb);
  }
  
  // Segédfüggvény a hálózati kép megjelenítéséhez
  Widget _getNetworkImage(String? logoUrl, bool isDarkMode, bool isWeb) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Icon(
        Icons.sports_soccer, 
        size: 24,
        color: isDarkMode ? Colors.white70 : Colors.black54,
      );
    }
    
    // Proxy használata a webes verzióban
    String proxyUrl = logoUrl;
    if (kIsWeb) {
      // Ha SVG formátumú a kép, közvetlenül használjuk
      if (logoUrl.toLowerCase().endsWith('.svg') || logoUrl.toLowerCase().contains('.svg')) {
        proxyUrl = logoUrl;
      } else {
        proxyUrl = 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(logoUrl)}';
      }
    }
    
    return Image.network(
      proxyUrl,
      fit: BoxFit.contain,
      width: 24,
      height: 24,
      headers: kIsWeb ? {'Origin': 'null'} : null,
      errorBuilder: (context, error, stackTrace) {
        print("Eredeti logó betöltési hiba: $error");
        return Icon(
          Icons.sports_soccer, 
          size: 24,
          color: isDarkMode ? Colors.white70 : Colors.black54,
        );
      },
    );
  }
}

// Simple widget for just the blinking dot - NO LONGER USED FOR LIVE, but kept for potential future use
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot({Key? key}) : super(key: key);

  @override
  __BlinkingDotState createState() => __BlinkingDotState();
}

class __BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BlinkingLiveIndicator extends StatefulWidget {
  const _BlinkingLiveIndicator({Key? key}) : super(key: key);

  @override
  __BlinkingLiveIndicatorState createState() => __BlinkingLiveIndicatorState();
}

class __BlinkingLiveIndicatorState extends State<_BlinkingLiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fetch localization safely
    final localizations = AppLocalizations.of(context);
    final liveText = localizations?.liveStatus ?? 'LIVE'; // Default to 'LIVE'

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _opacityAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
        Text(
          liveText, // Use the fetched or default string
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
} 