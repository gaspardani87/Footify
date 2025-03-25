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
  Map<String, dynamic>? _nationalTeamStandings;

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
    
    debugPrint('Dashboard betöltése, nemzeti csapat ID: $favoriteNationalTeamId');
    
    // Ne állítsuk be a zászló URL-t az adatbázisban, mindig ID alapján jelenítjük meg
    Map<String, dynamic> updatedUserData = Map<String, dynamic>.from(userData);
    
    // Load matches for selected date
    await _loadMatchesForDay(_formatDate(_selectedDate));
    
    // Get upcoming matches for the week
    final upcomingMatchesData = await DashboardService.getUpcomingMatches();
    
    // Load team's league and standings data
    if (favoriteTeamId != null && favoriteTeamId.isNotEmpty) {
      // Get the team's league information
      final teamLeagueData = await DashboardService.getTeamLeague(favoriteTeamId);
      debugPrint('Team league data received: ${teamLeagueData.containsKey('error') ? 'Error' : 'Success'}');
      
      if (!teamLeagueData.containsKey('error') && teamLeagueData['standings'] != null) {
        setState(() {
          _leagueStandings = teamLeagueData['standings'];
          
          // Mérkőzésnap hozzáadása közvetlenül a standings objektumhoz a league adatokból
          if (teamLeagueData['league'] != null && 
              teamLeagueData['league']['currentSeason'] != null && 
              teamLeagueData['league']['currentSeason']['currentMatchday'] != null) {
            
            // Ha a standings objektum még nem létezik vagy null, akkor üres Map-et hozunk létre
            if (_leagueStandings == null) {
              _leagueStandings = {};
            }
            
            // Adjuk hozzá a mérkőzésnap információt a standings objektumhoz
            _leagueStandings!['season'] = {
              'currentMatchday': teamLeagueData['league']['currentSeason']['currentMatchday']
            };
          }
          
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
      debugPrint('National team competition data received: ${nationalTeamLeagueData.containsKey('error') ? 'Error' : 'Success'}');
      
      // If no team league standings but national team standings available, use those instead
      if (_leagueStandings == null && !nationalTeamLeagueData.containsKey('error') && 
          nationalTeamLeagueData['standings'] != null) {
        setState(() {
          _leagueStandings = nationalTeamLeagueData['standings'];
          
          // Mérkőzésnap hozzáadása közvetlenül a standings objektumhoz a competition adatokból
          if (nationalTeamLeagueData['competition'] != null && 
              nationalTeamLeagueData['competition']['currentSeason'] != null && 
              nationalTeamLeagueData['competition']['currentSeason']['currentMatchday'] != null) {
            
            // Ha a standings objektum még nem létezik vagy null, akkor üres Map-et hozunk létre
            if (_leagueStandings == null) {
              _leagueStandings = {};
            }
            
            // Adjuk hozzá a mérkőzésnap információt a standings objektumhoz
            _leagueStandings!['season'] = {
              'currentMatchday': nationalTeamLeagueData['competition']['currentSeason']['currentMatchday']
            };
          }
          
          debugPrint('Using national team standings instead: ${_leagueStandings != null ? 'Data available' : 'Null data'}');
        });
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
    final String favoriteTeam = userData['favoriteTeam'] ?? '';
    final String favoriteTeamId = userData['favoriteTeamId'] ?? '';
    
    // Get standings data
    final standings = _leagueStandings?['standings']?[0]?['table'] ?? [];
    final competition = _leagueStandings?['competition'] ?? {};
    final String leagueName = competition['name'] ?? 'League';
    
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
    
    final String? leagueLogo = competition['emblem'];
    
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
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                        const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
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
      height: 70, // Magasságot növeltem, hogy elférjen két sor
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
                controller: ScrollController(
                  initialScrollOffset: _findTodayScrollOffset(),
                ),
                itemBuilder: (context, index) {
                  final date = _dateRange[index];
                  final isSelected = index == _currentDateIndex;
                  final isToday = _isToday(date);
                  final isTomorrow = _isTomorrow(date);
                  final isYesterday = _isYesterday(date);
                  
                  final double buttonWidth = isYesterday || isTomorrow ? 90.0 : 70.0;
                  
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
                              padding: const EdgeInsets.only(bottom: 0),
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
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => _changeDate(1),
          ),
        ],
      ),
    );
  }
  
  double _findTodayScrollOffset() {
    // A ma gomb a _dateRange lista közepén van (index 2), 
    // de ahhoz, hogy a képernyő közepén jelenjen meg, figyelembe kell vennünk
    // a képernyő szélességét és a gombok szélességét.

    // Mivel 5 nap van a listában, és a középső a mai nap (index 2)
    // Akkor az első két gomb szélességét és a margókat kell figyelembe vennünk

    // Yesterday gomb = 90 pixel széles + 8 pixel margó (2*4)
    // A többi gomb = 70 pixel széles + 8 pixel margó (2*4)
    // Az első két gomb (indexes 0 és 1) egyike lehet "Yesterday"

    // Ellenőrizzük, hogy a tegnapi nap melyik pozícióban van
    bool isYesterdayAtIndex0 = _isYesterday(_dateRange[0]);
    bool isYesterdayAtIndex1 = _isYesterday(_dateRange[1]);
    
    // Az offset számítása: az első gomb és a második gomb szélessége + margók
    double firstButtonWidth = isYesterdayAtIndex0 ? 90.0 : 70.0;
    double secondButtonWidth = isYesterdayAtIndex1 ? 90.0 : 70.0;
    
    // A teljes offset = a két gomb szélessége + a margók (mindkét gomb előtt és után)
    return firstButtonWidth + secondButtonWidth + (4 * 8.0);
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
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1D1D1D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF292929) : Colors.white,
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