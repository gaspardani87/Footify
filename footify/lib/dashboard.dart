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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _leagueStandings;
  Map<String, dynamic>? _nextMatch;
  Map<String, dynamic>? _nationalTeamNextMatch;
  List<dynamic> _matchesByDay = [];
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _dateRange = [];
  int _currentDateIndex = 2; // Default to middle date (today)
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _generateDateRange();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Load data after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _generateDateRange() {
    // Generate 5 days centered around selected date
    _dateRange = [];
    for (int i = -2; i <= 2; i++) {
      _dateRange.add(_selectedDate.add(Duration(days: i)));
    }
    _currentDateIndex = 2; // Always keep selected date in the middle
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    final provider = Provider.of<FirebaseProvider>(context, listen: false);
    final userData = provider.userData;

    // If not logged in, show login page and just load matches
    if (userData == null) {
      await _loadMatchesForDay(_formatDate(_selectedDate));
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Get favorite team and league info
    final String? favoriteTeamId = userData['favoriteTeamId'];
    final String? favoriteNationalTeamId = userData['favoriteNationalTeamId'];
    
    // Load matches for selected date
    await _loadMatchesForDay(_formatDate(_selectedDate));
    
    // Get upcoming matches for the week
    final upcomingMatchesData = await DashboardService.getUpcomingMatches();
    
    // Load team logos and info
    Map<String, dynamic> updatedUserData = Map<String, dynamic>.from(userData);
    
    // Load team's league and standings data
    if (favoriteTeamId != null && favoriteTeamId.isNotEmpty) {
      // Get the team's league information
      final teamLeagueData = await DashboardService.getTeamLeague(favoriteTeamId);
      debugPrint('Team league data received: ${teamLeagueData.containsKey('error') ? 'Error' : 'Success'}');
      
      if (!teamLeagueData.containsKey('error') && teamLeagueData['standings'] != null) {
        setState(() {
          _leagueStandings = teamLeagueData['standings'];
          debugPrint('League standings updated with ${_leagueStandings != null ? 'data' : 'null'}');
        });
        
        // Save team logo if available and not already saved
        if (teamLeagueData['team'] != null && 
            teamLeagueData['team']['crest'] != null &&
            (!userData.containsKey('favoriteTeamLogo') || userData['favoriteTeamLogo'] == null)) {
          updatedUserData['favoriteTeamLogo'] = teamLeagueData['team']['crest'];
          provider.updateUserSettings(updatedUserData);
          debugPrint('Updated favorite team logo in user settings');
        }
      } else {
        debugPrint('No league standings available: ${teamLeagueData['message'] ?? 'Unknown error'}');
      }
      
      // Load team's next match
      final nextMatchData = await DashboardService.getNextMatch(favoriteTeamId);
      if (!nextMatchData.containsKey('error') && nextMatchData['match'] != null) {
        setState(() {
          _nextMatch = nextMatchData['match'];
        });
      }
    }

    // Load national team's next match if available
    if (favoriteNationalTeamId != null && favoriteNationalTeamId.isNotEmpty) {
      // Get the national team's competition information
      final nationalTeamLeagueData = await DashboardService.getNationalTeamLeague(favoriteNationalTeamId);
      debugPrint('National team competition data: ${nationalTeamLeagueData.containsKey('error') ? 'Error' : 'Success'}');
      
      // If no team league standings but national team standings available, use those instead
      if (_leagueStandings == null && !nationalTeamLeagueData.containsKey('error') && 
          nationalTeamLeagueData['standings'] != null) {
        setState(() {
          _leagueStandings = nationalTeamLeagueData['standings'];
          debugPrint('Using national team standings instead');
        });
        
        // Save national team logo if available and not already saved
        if (nationalTeamLeagueData['team'] != null && 
            nationalTeamLeagueData['team']['crest'] != null &&
            (!userData.containsKey('favoriteNationalTeamLogo') || userData['favoriteNationalTeamLogo'] == null)) {
          updatedUserData['favoriteNationalTeamLogo'] = nationalTeamLeagueData['team']['crest'];
          provider.updateUserSettings(updatedUserData);
          debugPrint('Updated favorite national team logo in user settings');
        }
      }
      
      // Get national team's next match
      final nationalTeamMatchData = await DashboardService.getNationalTeamNextMatch(favoriteNationalTeamId);
      if (!nationalTeamMatchData.containsKey('error') && nationalTeamMatchData['match'] != null) {
        setState(() {
          _nationalTeamNextMatch = nationalTeamMatchData['match'];
        });
      }
    }

    setState(() {
      _isLoading = false;
    });
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
  
  Future<void> _loadMatchesForDay(String date) async {
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
    // Set animation direction
    _slideAnimation = Tween<Offset>(
      begin: Offset(direction.toDouble() * -1, 0), // -1 for right, 1 for left
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward(from: 0.0);
    
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: direction));
      _generateDateRange(); // This will rebuild the date range around the selected date
    });
    
    _loadMatchesForDay(_formatDate(_selectedDate));
  }
  
  void _selectDate(DateTime date, int index) {
    if (index == _currentDateIndex) return;
    
    // Set animation direction
    _slideAnimation = Tween<Offset>(
      begin: Offset((index - _currentDateIndex).toDouble() * -0.2, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward(from: 0.0);
    
    setState(() {
      _selectedDate = date;
      // Always regenerate date range to keep selected date in middle
      _generateDateRange();
      // Now current date index will always be 2 (middle)
    });
    
    _loadMatchesForDay(_formatDate(date));
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppLocalizations.of(context)?.loginToViewDashboard ?? 'Log in to view your personalized dashboard',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
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
                  });
                  _loadMatchesForDay(_formatDate(_selectedDate));
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
                const SizedBox(width: 12),
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
              _buildNextMatchBox(),
            
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
                    });
                    _loadMatchesForDay(_formatDate(_selectedDate));
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
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: favoriteTeamId.isNotEmpty 
            ? () => _navigateToTeamDetails(favoriteTeamId, favoriteTeam)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)?.favoriteTeam ?? 'Favorite Team',
                style: const TextStyle(
                  color: Color(0xFFFFE6AC),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
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
                    child: Text(
                      favoriteTeam.isNotEmpty ? favoriteTeam : AppLocalizations.of(context)?.noTeamSelected ?? 'No team selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteNationBox(Map<String, dynamic> userData) {
    final String favoriteNation = userData['favoriteNationalTeam'] ?? '';
    final String favoriteNationId = userData['favoriteNationalTeamId'] ?? '';
    final String? nationLogo = userData['favoriteNationalTeamLogo'];
    
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: favoriteNationId.isNotEmpty 
            ? () => _navigateToTeamDetails(favoriteNationId, favoriteNation)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)?.favoriteNation ?? 'Favorite Nation',
                style: const TextStyle(
                  color: Color(0xFFFFE6AC),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  nationLogo != null && nationLogo.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          _getProxiedImageUrl(nationLogo),
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.flag,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 24,
                      ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      favoriteNation.isNotEmpty ? favoriteNation : AppLocalizations.of(context)?.noNationSelected ?? 'No nation selected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeagueStandingsBox(Map<String, dynamic> userData) {
    final String favoriteTeam = userData['favoriteTeam'] ?? '';
    final String favoriteTeamId = userData['favoriteTeamId'] ?? '';
    
    // Get standings data
    final standings = _leagueStandings?['standings']?[0]?['table'] ?? [];
    final competition = _leagueStandings?['competition'] ?? {};
    final String leagueName = competition['name'] ?? 'League';
    final int matchday = competition['currentSeason']?['currentMatchday'] ?? 0;
    final String? leagueLogo = competition['emblem'];
    
    // Debug print to check standings data structure
    print('League Standings: ${standings.length} teams available');
    
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
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(8),
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
                  borderRadius: isFavorite ? BorderRadius.circular(4) : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        position.toString(),
                        style: TextStyle(
                          color: Colors.white,
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
                                color: isFavorite ? const Color(0xFFFFE6AC) : Colors.white,
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
                          color: Colors.white,
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
                          color: Colors.white,
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
                          color: Colors.white,
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
                          color: Colors.white,
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
                          color: isFavorite ? const Color(0xFFFFE6AC) : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNextMatchBox() {
    // Use team match if available, otherwise national team match
    final matchData = _nextMatch ?? _nationalTeamNextMatch;
    if (matchData == null) return const SizedBox.shrink();
    
    final competition = matchData['competition'] ?? {'name': 'Unknown'};
    final homeTeam = matchData['homeTeam'] ?? {'name': 'Home'};
    final awayTeam = matchData['awayTeam'] ?? {'name': 'Away'};
    final String? competitionLogo = competition['emblem'];
    final String? homeTeamLogo = homeTeam['crest'];
    final String? awayTeamLogo = awayTeam['crest'];
    
    // Parse match date
    DateTime matchDate;
    try {
      matchDate = DateTime.parse(matchData['utcDate']);
    } catch (e) {
      matchDate = DateTime.now().add(const Duration(days: 1));
    }
    
    final formattedDate = DateFormat('MMM d, yyyy').format(matchDate);
    final formattedTime = DateFormat('HH:mm').format(matchDate);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Competition header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    competitionLogo != null && competitionLogo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            _getProxiedImageUrl(competitionLogo),
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
                      competition['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Text(
                  AppLocalizations.of(context)?.nextMatch ?? 'Next Match',
                  style: const TextStyle(
                    color: Color(0xFFFFE6AC),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Teams and match time
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Home team
                Expanded(
                  child: InkWell(
                    onTap: () => _navigateToTeamDetails(
                      homeTeam['id'].toString(), 
                      homeTeam['name']
                    ),
                    child: Column(
                      children: [
                        homeTeamLogo != null && homeTeamLogo.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                _getProxiedImageUrl(homeTeamLogo),
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.sports_soccer,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.sports_soccer,
                              color: Colors.white,
                              size: 30,
                            ),
                        const SizedBox(height: 8),
                        Text(
                          homeTeam['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Match time and date
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formattedTime,
                        style: const TextStyle(
                          color: Color(0xFFFFE6AC),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Away team
                Expanded(
                  child: InkWell(
                    onTap: () => _navigateToTeamDetails(
                      awayTeam['id'].toString(), 
                      awayTeam['name']
                    ),
                    child: Column(
                      children: [
                        awayTeamLogo != null && awayTeamLogo.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                _getProxiedImageUrl(awayTeamLogo),
                                width: 60,
                                height: 60,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.sports_soccer,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.sports_soccer,
                              color: Colors.white,
                              size: 30,
                            ),
                        const SizedBox(height: 8),
                        Text(
                          awayTeam['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Widget _buildDateSelector() {
    return Container(
      height: 60,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => _changeDate(-1),
          ),
          Expanded(
            child: SlideTransition(
              position: _slideAnimation,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _dateRange.length,
                itemBuilder: (context, index) {
                  final date = _dateRange[index];
                  final isSelected = index == _currentDateIndex;
                  final isToday = _isToday(date);
                  final isTomorrow = _isTomorrow(date);
                  final isYesterday = _isYesterday(date);
                  
                  String dateLabel;
                  if (isToday) {
                    dateLabel = AppLocalizations.of(context)?.today ?? 'Today';
                  } else if (isTomorrow) {
                    dateLabel = AppLocalizations.of(context)?.tomorrow ?? 'Tomorrow';
                  } else if (isYesterday) {
                    dateLabel = AppLocalizations.of(context)?.yesterday ?? 'Yesterday';
                  } else {
                    dateLabel = DateFormat('MMM d').format(date);
                  }
                  
                  return InkWell(
                    onTap: () => _selectDate(date, index),
                    child: Container(
                      width: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFE6AC) : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          dateLabel,
                          style: TextStyle(
                            color: isSelected ? Colors.black : isToday ? const Color(0xFFFFE6AC) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                },
              ),
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
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
  
  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day;
  }
  
  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }
  
  Widget _buildMatchesForDay() {
    if (_matchesByDay.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
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
    }
    
    // Group matches by competition
    Map<String, List<dynamic>> matchesByCompetition = {};
    for (var match in _matchesByDay) {
      final competitionName = match['competition']['name'];
      if (!matchesByCompetition.containsKey(competitionName)) {
        matchesByCompetition[competitionName] = [];
      }
      matchesByCompetition[competitionName]!.add(match);
    }
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              ...matches.map((match) => _buildMatchItem(match)).toList(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchItem(dynamic match) {
    final homeTeam = match['homeTeam'];
    final awayTeam = match['awayTeam'];
    final String? homeTeamLogo = homeTeam['crest'];
    final String? awayTeamLogo = awayTeam['crest'];
    
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
      color: const Color(0xFF292929),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Match time
            SizedBox(
              width: 50,
              child: Text(
                formattedTime,
                style: const TextStyle(
                  color: Colors.white,
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
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (homeTeamLogo != null && homeTeamLogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                AppLocalizations.of(context)?.versus ?? 'vs',
                style: const TextStyle(
                  color: Color(0xFFFFE6AC),
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
                      padding: const EdgeInsets.only(right: 8.0),
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
                        style: const TextStyle(
                          color: Colors.white,
                        ),
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
} 