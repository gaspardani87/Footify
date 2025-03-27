// match_details.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:footify/theme_provider.dart';
import 'package:footify/color_blind_mode_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:footify/common_layout.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class FootballApiService {
  static String baseUrl = 'https://us-central1-footify-13da4.cloudfunctions.net';
  static bool _initialized = true;

  static void initialize(String firebaseProjectId) {
    baseUrl = 'https://us-central1-$firebaseProjectId.cloudfunctions.net';
    _initialized = true;
    print('FootballApiService initialized with base URL: $baseUrl');
  }

  static Future<Map<String, dynamic>> getTeamMatches(
    int teamId, {
    String? status,
    String? dateFrom,
    String? dateTo,
    int limit = 10
  }) async {
    try {
      Map<String, String> queryParams = {
        'id': teamId.toString(),
        'limit': limit.toString(),
      };
      
      if (status != null) queryParams['status'] = status;
      if (dateFrom != null) queryParams['dateFrom'] = dateFrom;
      if (dateTo != null) queryParams['dateTo'] = dateTo;
      
      final response = await http.get(
        Uri.parse('$baseUrl/fetchTeamMatches').replace(
          queryParameters: queryParams
        )
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('matches')) {
          return data;
        } else {
          print('Invalid data format from team matches API for team $teamId');
          return {'matches': []};
        }
      } else {
        print('Team matches API error: ${response.statusCode}');
        return {'matches': []};
      }
    } catch (e) {
      print('Error in getTeamMatches: $e');
      return {'matches': []};
    }
  }

  static Future<Map<String, dynamic>> getHeadToHead(int team1Id, int team2Id, {int limit = 10}) async {
    try {
      // Get matches for the first team
      final team1Matches = await getTeamMatches(team1Id, limit: limit * 2);
      
      if (!team1Matches.containsKey('matches') || team1Matches['matches'] is! List) {
        return {'matches': []};
      }
      
      // Filter for matches against the second team
      final List<dynamic> allMatches = team1Matches['matches'];
      final List<dynamic> h2hMatches = allMatches.where((match) {
        final int homeTeamId = match['homeTeam']?['id'] ?? 0;
        final int awayTeamId = match['awayTeam']?['id'] ?? 0;
        return (homeTeamId == team1Id && awayTeamId == team2Id) || 
               (homeTeamId == team2Id && awayTeamId == team1Id);
      }).take(limit).toList();
      
      return {'matches': h2hMatches};
    } catch (e) {
      print('Error in getHeadToHead: $e');
      return {'matches': []};
    }
  }

  static Future<Map<String, dynamic>> getMatchStatistics(int matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fetchMatchById').replace(
          queryParameters: {'id': matchId.toString()}
        )
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final matchData = json.decode(response.body);
        return {'statistics': matchData['statistics'] ?? {}};
      } else {
        return {'statistics': {}};
      }
    } catch (e) {
      print('Error in getMatchStatistics: $e');
      return {'statistics': {}};
    }
  }
}

class MatchDetailsPage extends StatefulWidget {
  final Map<String, dynamic> matchData;

  const MatchDetailsPage({
    super.key,
    required this.matchData,
  });

  @override
  _MatchDetailsPageState createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends State<MatchDetailsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, Color> colors = {};
  bool _isLoading = true;
  
  // Variables to store related match data
  List<dynamic> _homeTeamRecentMatches = [];
  List<dynamic> _awayTeamRecentMatches = [];
  List<dynamic> _headToHeadMatches = [];
  
  // Statistics calculated from recent matches
  Map<String, dynamic> _homeTeamStats = {
    'recent': {'wins': 0, 'draws': 0, 'losses': 0},
    'goals': {'scored': 0, 'conceded': 0},
  };
  
  Map<String, dynamic> _awayTeamStats = {
    'recent': {'wins': 0, 'draws': 0, 'losses': 0},
    'goals': {'scored': 0, 'conceded': 0},
  };
  
  Map<String, dynamic> _h2hStats = {
    'homeWins': 0,
    'awayWins': 0,
    'draws': 0,
  };

  @override
  void initState() {
    super.initState();
    // Create a TabController with 5 tabs: Overview, Timeline, Stats, Lineups, H2H, Players
    _tabController = TabController(length: 6, vsync: this);

    // Initialize the FootballAPIService with the correct Firebase project ID
    // This should match your Firebase project ID where the functions are deployed
    FootballApiService.initialize('footify-13da4'); // Update this with your actual project ID
    
    // Call the method to fetch additional data
    _fetchRelatedMatchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  dynamic _getNestedValue(Map<String, dynamic> map, List<String> keys, dynamic defaultValue) {
    dynamic current = map;
    for (String key in keys) {
      if (current is! Map || !current.containsKey(key)) {
        return defaultValue;
      }
      current = current[key];
    }
    return current ?? defaultValue;
  }

  // Format date in standard format
  String _formatDate(DateTime date) {
    final DateFormat formatter = DateFormat('dd MMM yyyy');
    return formatter.format(date);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final homeTeam = widget.matchData['homeTeam']['name'];
    final awayTeam = widget.matchData['awayTeam']['name'];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    colors = {
      homeTeam: isDarkMode ? const Color(0xFFFFE6AC) : const Color(0xFF2C3E50),
      awayTeam: isDarkMode ? Colors.white : Colors.black,
      'text': isDarkMode ? Colors.white : Colors.black,
      'textSecondary': isDarkMode ? Colors.grey[400]! : Colors.grey[600]!,
      'surface': isDarkMode ? const Color(0xFF292929) : Colors.white,
      'divider': isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
      'primary': const Color(0xFFFFE6AC),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Get theme brightness for background color
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.grey[900] : Colors.grey[100];
    
    final homeTeamName = widget.matchData['homeTeam']['name'];
    final awayTeamName = widget.matchData['awayTeam']['name'];
    final homeTeamColor = _generateTeamColor(homeTeamName);
    final awayTeamColor = _generateTeamColor(awayTeamName);
    
    // Extract score
    final score = widget.matchData['score'] ?? {};
    final fullTimeScore = score['fullTime'] ?? {};
    final homeScore = fullTimeScore['home'] ?? 0;
    final awayScore = fullTimeScore['away'] ?? 0;
    
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF121212) 
          : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 240.0,
                floating: false,
                pinned: true,
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF1D1D1D) 
                    : Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          homeTeamColor.withOpacity(0.7),
                          awayTeamColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Competition name and match day
                          Text(
                            _getCompetitionName(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Teams and score
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Home team
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildTeamLogo(widget.matchData['homeTeam']['crest'], size: 60),
                                    const SizedBox(height: 8),
                                    Text(
                                      homeTeamName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Score
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$homeScore - $awayScore',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              
                              // Away team
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildTeamLogo(widget.matchData['awayTeam']['crest'], size: 60),
                                    const SizedBox(height: 8),
                                    Text(
                                      awayTeamName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
                          
                          // Match status and time
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _getMatchStatusAndTime(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          
                          // Goalscorers (if any)
                          const SizedBox(height: 8),
                          _buildGoalscorersTextSummary(),
                        ],
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFFFFE6AC) 
                    : Colors.blue,
                  labelColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFFFFE6AC) 
                    : Colors.blue,
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.sports_soccer),
                      text: 'Overview',
                    ),
                    Tab(
                      icon: Icon(Icons.timeline),
                      text: 'Timeline',
                    ),
                    Tab(
                      icon: Icon(Icons.bar_chart),
                      text: 'Stats',
                    ),
                    Tab(
                      icon: Icon(Icons.people),
                      text: 'Lineup',
                    ),
                    Tab(
                      icon: Icon(Icons.compare_arrows),
                      text: 'H2H',
                    ),
                    Tab(
                      icon: Icon(Icons.person),
                      text: 'Players',
                    ),
                  ],
                ),
              ),
            ];
          },
          body: _isLoading
            ? _buildLoadingIndicator()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildTimelineTab(),
                  _buildStatsTab(),
                  _buildLineupTab(),
                  _buildH2HTab(),
                  _buildPlayersTab(),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading match data...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchStatsTab() {
    return _isLoading 
      ? _buildLoadingIndicator() 
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Match header with teams, logos, and score
              _buildMatchHeader(),
              
          const SizedBox(height: 24),
              
              // Goals section
              _buildGoalsSection(),
              
              const SizedBox(height: 32),
              
              // Key stats with visualizations
              _buildKeyStatsSection(),
            ],
          ),
        );
  }

  Widget _buildGoalsSection() {
    // Extract goals data
    final goals = _extractGoals();
    if (goals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No goals in this match yet', style: TextStyle(fontSize: 16)),
        ),
      );
    }
    
    final homeTeamId = widget.matchData['homeTeam']['id'];
    
    // Group goals by team
    final homeGoals = goals.where((goal) => goal['teamId'] == homeTeamId).toList();
    final awayGoals = goals.where((goal) => goal['teamId'] != homeTeamId).toList();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sports_soccer, size: 20),
                SizedBox(width: 8),
                Text(
                  'Goals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Home team goals
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var goal in homeGoals)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(
                                  '${goal['minute']}\'',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    goal['playerName'] ?? 'Unknown Player',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (goal['isOwnGoal'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'OG',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                if (goal['isPenalty'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'P',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (homeGoals.isEmpty)
                          const Center(child: Text('-', style: TextStyle(color: Colors.grey))),
                      ],
                    ),
                  ),
                  // Vertical divider
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: VerticalDivider(thickness: 1),
                  ),
                  // Away team goals
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var goal in awayGoals)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (goal['isOwnGoal'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'OG',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                if (goal['isPenalty'] == true)
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'P',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    goal['playerName'] ?? 'Unknown Player',
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${goal['minute']}\'',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        if (awayGoals.isEmpty)
                          const Center(child: Text('-', style: TextStyle(color: Colors.grey))),
                      ],
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

  List<Map<String, dynamic>> _extractGoals() {
    final List<Map<String, dynamic>> extractedGoals = [];
    final goals = widget.matchData['goals'] ?? [];
    
    if (goals is! List) {
      return extractedGoals;
    }
    
    for (final goal in goals) {
      if (goal is Map<String, dynamic>) {
        final Map<String, dynamic> extractedGoal = {
          'minute': goal['minute'] ?? 0,
          'playerName': goal['scorer']?['name'] ?? goal['player']?['name'] ?? 'Unknown Player',
          'playerId': goal['scorer']?['id'] ?? goal['player']?['id'],
          'teamId': goal['team']?['id'],
          'teamName': goal['team']?['name'] ?? 'Unknown Team',
          'isOwnGoal': goal['type'] == 'OWN' || goal['ownGoal'] == true,
          'isPenalty': goal['type'] == 'PENALTY' || goal['penalty'] == true,
          'assistPlayerName': goal['assist']?['name'] ?? goal['assistedBy']?['name'],
          'assistPlayerId': goal['assist']?['id'] ?? goal['assistedBy']?['id'],
          'injuryTime': goal['injuryTime'] ?? 0,
        };
        extractedGoals.add(extractedGoal);
      }
    }
    
    // Sort goals by minute and injury time
    extractedGoals.sort((a, b) {
      int minuteComparison = (a['minute'] ?? 0).compareTo(b['minute'] ?? 0);
      if (minuteComparison == 0) {
        return (a['injuryTime'] ?? 0).compareTo(b['injuryTime'] ?? 0);
      }
      return minuteComparison;
    });
    
    return extractedGoals;
  }

  Widget _buildKeyStatsSection() {
    // Get basic match statistics from the match data
    final basicStats = _getMatchStats();
    
    // If we're using our enhanced statistics endpoint, let's get additional stats
    final Map<String, dynamic> matchData = widget.matchData;
    
    // Ensure statistics is a Map<String, dynamic>
    final Map<String, dynamic> statistics = {};
    if (matchData['statistics'] is Map) {
      (matchData['statistics'] as Map).forEach((key, value) {
        statistics[key.toString()] = value;
      });
    }
    
    // Additional statistics from our enhanced endpoint
    final cards = statistics['cards'];
    final goals = statistics['goals'];
    final possession = statistics['possession'];
    
    Map<String, dynamic> homeCards = {'yellow': 0, 'red': 0};
    Map<String, dynamic> awayCards = {'yellow': 0, 'red': 0};
    if (cards is Map) {
      if (cards['home'] is Map) {
        homeCards = Map<String, dynamic>.from(cards['home'] as Map);
      }
      if (cards['away'] is Map) {
        awayCards = Map<String, dynamic>.from(cards['away'] as Map);
      }
    }
    
    Map<String, dynamic> homeGoals = {'total': 0, 'firstHalf': 0, 'secondHalf': 0};
    Map<String, dynamic> awayGoals = {'total': 0, 'firstHalf': 0, 'secondHalf': 0};
    if (goals is Map) {
      if (goals['home'] is Map) {
        homeGoals = Map<String, dynamic>.from(goals['home'] as Map);
      }
      if (goals['away'] is Map) {
        awayGoals = Map<String, dynamic>.from(goals['away'] as Map);
      }
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Key Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Standard stats from original data
            for (var stat in basicStats) ...[
              _buildStatRow(
                stat['label'] ?? '',
                stat['homeValue'] ?? '0',
                stat['awayValue'] ?? '0',
                isPercentage: (stat['label'] ?? '') == 'Possession' || (stat['label'] ?? '') == 'Pass Accuracy',
              ),
              const SizedBox(height: 12),
            ],
            // Show cards statistics if available
            if (cards != null) ...[
              _buildStatRow(
                'Yellow Cards',
                homeCards['yellow']?.toString() ?? '0',
                awayCards['yellow']?.toString() ?? '0',
                isPercentage: false,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Red Cards',
                homeCards['red']?.toString() ?? '0',
                awayCards['red']?.toString() ?? '0',
                isPercentage: false,
              ),
              const SizedBox(height: 12),
            ],
            // Show goals by half if available
            if (goals != null) ...[
              _buildStatRow(
                'Goals (1st Half)',
                homeGoals['firstHalf']?.toString() ?? '0',
                awayGoals['firstHalf']?.toString() ?? '0',
                isPercentage: false,
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Goals (2nd Half)',
                homeGoals['secondHalf']?.toString() ?? '0',
                awayGoals['secondHalf']?.toString() ?? '0',
                isPercentage: false,
              ),
              const SizedBox(height: 12),
            ],
            // Additional statistics that might be in the enhanced API
            if (statistics['shotsOnGoal'] != null) ...[
              _buildStatRow(
                'Shots on Goal',
                statistics['shotsOnGoal']?['home']?.toString() ?? '0',
                statistics['shotsOnGoal']?['away']?.toString() ?? '0',
                isPercentage: false,
              ),
              const SizedBox(height: 12),
            ],
            if (statistics['fouls'] != null) ...[
              _buildStatRow(
                'Fouls',
                statistics['fouls']?['home']?.toString() ?? '0',
                statistics['fouls']?['away']?.toString() ?? '0',
                isPercentage: false,
              ),
              const SizedBox(height: 12),
            ],
            if (statistics['corners'] != null) ...[
              _buildStatRow(
                'Corners',
                statistics['corners']?['home']?.toString() ?? '0',
                statistics['corners']?['away']?.toString() ?? '0',
                isPercentage: false,
              ),
              const SizedBox(height: 12),
            ],
            if (statistics['offsides'] != null) ...[
              _buildStatRow(
                'Offsides',
                statistics['offsides']?['home']?.toString() ?? '0',
                statistics['offsides']?['away']?.toString() ?? '0',
                isPercentage: false,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _getMatchStats() {
    final List<Map<String, String>> stats = [];
    final homeTeam = widget.matchData['homeTeam'];
    final awayTeam = widget.matchData['awayTeam'];
    final statistics = widget.matchData['statistics'] ?? {};

    // Basic match stats
    stats.add({
      'label': 'Possession',
      'homeValue': statistics['home_possession']?.toString() ?? '0',
      'awayValue': statistics['away_possession']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Shots on Target',
      'homeValue': statistics['home_shots_on_target']?.toString() ?? '0',
      'awayValue': statistics['away_shots_on_target']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Total Shots',
      'homeValue': statistics['home_shots']?.toString() ?? '0',
      'awayValue': statistics['away_shots']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Pass Accuracy',
      'homeValue': statistics['home_pass_accuracy']?.toString() ?? '0',
      'awayValue': statistics['away_pass_accuracy']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Total Passes',
      'homeValue': statistics['home_passes']?.toString() ?? '0',
      'awayValue': statistics['away_passes']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Fouls',
      'homeValue': statistics['home_fouls']?.toString() ?? '0',
      'awayValue': statistics['away_fouls']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Yellow Cards',
      'homeValue': (widget.matchData['bookings'] ?? [])
          .where((booking) => booking['team']['id'] == homeTeam['id'] && booking['card'] == 'YELLOW')
          .length
          .toString(),
      'awayValue': (widget.matchData['bookings'] ?? [])
          .where((booking) => booking['team']['id'] == awayTeam['id'] && booking['card'] == 'YELLOW')
          .length
          .toString(),
    });

    stats.add({
      'label': 'Red Cards',
      'homeValue': (widget.matchData['bookings'] ?? [])
          .where((booking) => booking['team']['id'] == homeTeam['id'] && booking['card'] == 'RED')
          .length
          .toString(),
      'awayValue': (widget.matchData['bookings'] ?? [])
          .where((booking) => booking['team']['id'] == awayTeam['id'] && booking['card'] == 'RED')
          .length
          .toString(),
    });

    stats.add({
      'label': 'Corners',
      'homeValue': statistics['home_corners']?.toString() ?? '0',
      'awayValue': statistics['away_corners']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Offsides',
      'homeValue': statistics['home_offsides']?.toString() ?? '0',
      'awayValue': statistics['away_offsides']?.toString() ?? '0',
    });

    return stats;
  }

  Widget _buildStatRow(String label, String homeValue, String awayValue, {bool isPercentage = false}) {
    // Convert values to doubles for ratio calculation
    final double homeNum = double.tryParse(homeValue) ?? 0;
    final double awayNum = double.tryParse(awayValue) ?? 0;
    final double total = homeNum + awayNum;
    
    // Calculate ratios, default to 0.5 each if total is 0
    final double homeRatio = total > 0 ? homeNum / total : 0.5;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
              isPercentage ? '$homeValue%' : homeValue,
          style: TextStyle(
                fontWeight: homeNum > awayNum ? FontWeight.bold : FontWeight.normal,
                color: homeNum > awayNum ? Colors.blue : null,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              isPercentage ? '$awayValue%' : awayValue,
              style: TextStyle(
                fontWeight: awayNum > homeNum ? FontWeight.bold : FontWeight.normal,
                color: awayNum > homeNum ? Colors.blue : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2.5),
          child: SizedBox(
            height: 5,
            child: Row(
              children: [
                Expanded(
                  flex: (homeRatio * 100).round(),
                  child: Container(
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  flex: ((1 - homeRatio) * 100).round(),
                  child: Container(
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
    );
  }

  Widget _buildHeadToHeadSummary() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
          Text(
                  '${_h2hStats['homeWins'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                Text(widget.matchData['homeTeam']['name'], 
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            Column(
              children: [
                Text(
                  '${_h2hStats['draws'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Text('Draws', style: TextStyle(fontSize: 14)),
              ],
            ),
            Column(
              children: [
                Text(
                  '${_h2hStats['awayWins'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Text(widget.matchData['awayTeam']['name'], 
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRecentForm(String teamName, int wins, int draws, int losses) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teamName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('W', wins.toString(), Colors.green),
                _buildStatColumn('D', draws.toString(), Colors.orange),
                _buildStatColumn('L', losses.toString(), Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamGoalsStats(String teamName, int scored, int conceded) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teamName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Scored', scored.toString(), Colors.green),
                _buildStatColumn('Conceded', conceded.toString(), Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
            style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildRecentMatches(List<dynamic> matches, int teamId) {
    if (matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No recent matches available',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: matches.length > 5 ? 5 : matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        final bool isHome = match['homeTeam']['id'] == teamId;
        
        // Extract scores with proper type handling
        final dynamic rawHomeScore = match['score']?['fullTime']?['home'] ?? 0;
        final dynamic rawAwayScore = match['score']?['fullTime']?['away'] ?? 0;
        final int homeScore = rawHomeScore is num ? rawHomeScore.toInt() : 0;
        final int awayScore = rawAwayScore is num ? rawAwayScore.toInt() : 0;
        
        final String scoreText = '$homeScore - $awayScore';
        final String opponentName = isHome ? match['awayTeam']['name'] : match['homeTeam']['name'];
        
        // Determine result
        String result;
        Color resultColor;
        if (isHome) {
          if (homeScore > awayScore) {
            result = 'W';
            resultColor = Colors.green;
          } else if (homeScore < awayScore) {
            result = 'L';
            resultColor = Colors.red;
          } else {
            result = 'D';
            resultColor = Colors.amber;
          }
        } else {
          if (homeScore < awayScore) {
            result = 'W';
            resultColor = Colors.green;
          } else if (homeScore > awayScore) {
            result = 'L';
            resultColor = Colors.red;
          } else {
            result = 'D';
            resultColor = Colors.amber;
          }
        }
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: resultColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: resultColor),
                  ),
                  child: Center(
                    child: Text(
                      result,
                      style: TextStyle(
                        color: resultColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHome ? 'vs $opponentName (H)' : 'vs $opponentName (A)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        match['utcDate'] != null
                            ? _formatDate(DateTime.parse(match['utcDate']))
                            : 'Date unknown',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  scoreText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
      ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerDetailItem(String label, String value, IconData icon, Map<String, Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: colors['primary'], size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: colors['textSecondary'],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            value,
            style: TextStyle(
              color: colors['text'],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerStatCard(String label, String value, IconData icon, Map<String, Color> colors, Color iconColor) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: colors['text'],
                fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: colors['textSecondary'],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _getAllStats() {
    final List<Map<String, String>> stats = [];
    final homeTeam = widget.matchData['homeTeam'];
    final awayTeam = widget.matchData['awayTeam'];
    final statistics = widget.matchData['statistics'] ?? {};

    // Basic match stats
    stats.add({
      'label': 'Possession',
      'homeValue': statistics['home_possession']?.toString() ?? '0',
      'awayValue': statistics['away_possession']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Shots on Target',
      'homeValue': statistics['home_shots_on_target']?.toString() ?? '0',
      'awayValue': statistics['away_shots_on_target']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Total Shots',
      'homeValue': statistics['home_shots']?.toString() ?? '0',
      'awayValue': statistics['away_shots']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Pass Accuracy',
      'homeValue': statistics['home_pass_accuracy']?.toString() ?? '0',
      'awayValue': statistics['away_pass_accuracy']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Total Passes',
      'homeValue': statistics['home_passes']?.toString() ?? '0',
      'awayValue': statistics['away_passes']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Fouls',
      'homeValue': statistics['home_fouls']?.toString() ?? '0',
      'awayValue': statistics['away_fouls']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Yellow Cards',
      'homeValue': (widget.matchData['bookings'] ?? [])
          .where((booking) => booking['team']['id'] == homeTeam['id'] && booking['card'] == 'YELLOW')
          .length
          .toString(),
      'awayValue': (widget.matchData['bookings'] ?? [])
          .where((booking) => booking['team']['id'] == awayTeam['id'] && booking['card'] == 'YELLOW')
          .length
          .toString(),
    });

    stats.add({
      'label': 'Red Cards',
      'homeValue': (widget.matchData['bookings'] ?? [])
          .where((booking) => booking['team']['id'] == homeTeam['id'] && booking['card'] == 'RED')
          .length
          .toString(),
      'awayValue': (widget.matchData['bookings'] ?? [])
          .where((booking) => booking['team']['id'] == awayTeam['id'] && booking['card'] == 'RED')
          .length
          .toString(),
    });

    stats.add({
      'label': 'Corners',
      'homeValue': statistics['home_corners']?.toString() ?? '0',
      'awayValue': statistics['away_corners']?.toString() ?? '0',
    });

    stats.add({
      'label': 'Offsides',
      'homeValue': statistics['home_offsides']?.toString() ?? '0',
      'awayValue': statistics['away_offsides']?.toString() ?? '0',
    });

    return stats;
  }

  // Method to fetch related match data from the API
  Future<void> _fetchRelatedMatchData() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final homeTeamId = widget.matchData['homeTeam']['id'];
      final awayTeamId = widget.matchData['awayTeam']['id'];
      
      // Determine date range for fetching matches (last 3 months)
      final now = DateTime.now();
      final dateFrom = DateTime(now.year, now.month - 3, now.day);
      final dateTo = now;
      
      // Format dates for API
      final dateFromStr = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      final dateToStr = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      
      // Create a list of futures to execute in parallel
      List<Future> futures = [];
      
      // Home team matches future
      final homeTeamMatchesFuture = FootballApiService.getTeamMatches(
        homeTeamId,
        status: 'FINISHED',
        dateFrom: dateFromStr,
        dateTo: dateToStr,
        limit: 10,
      );
      futures.add(homeTeamMatchesFuture);
      
      // Away team matches future
      final awayTeamMatchesFuture = FootballApiService.getTeamMatches(
        awayTeamId,
        status: 'FINISHED',
        dateFrom: dateFromStr,
        dateTo: dateToStr,
        limit: 10,
      );
      futures.add(awayTeamMatchesFuture);
      
      // Head to head matches future
      final h2hMatchesFuture = FootballApiService.getHeadToHead(
        homeTeamId,
        awayTeamId,
        limit: 10,
      );
      futures.add(h2hMatchesFuture);
      
      // Current match detailed stats future
      final matchId = widget.matchData['id'];
      print('Fetching statistics for match ID: $matchId');
      final matchStatsFuture = FootballApiService.getMatchStatistics(matchId);
      futures.add(matchStatsFuture);
      
      // Execute all futures in parallel
      final results = await Future.wait(futures);
      
      // Process results
      final homeTeamMatches = results[0];
      final awayTeamMatches = results[1];
      final h2hMatches = results[2];
      final matchStats = results[3];
      
      print('Received match statistics: $matchStats');
      
      // Update state with new data
      if (mounted) {
        setState(() {
          // Update recent matches
          _homeTeamRecentMatches = homeTeamMatches['matches'] ?? [];
          _awayTeamRecentMatches = awayTeamMatches['matches'] ?? [];
          _headToHeadMatches = h2hMatches['matches'] ?? [];
          
          // If we received statistics, update the match data with them
          if (matchStats != null && matchStats.containsKey('statistics')) {
            widget.matchData['statistics'] = matchStats['statistics'];
          }
          
          // Calculate stats from recent matches
          _calculateStats();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching related match data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Calculate statistics from matches data
  void _calculateStats() {
    // Initialize counters
    int homeWins = 0, homeDraws = 0, homeLosses = 0;
    int awayWins = 0, awayDraws = 0, awayLosses = 0;
    int homeScored = 0, homeConceded = 0;
    int awayScored = 0, awayConceded = 0;
    int h2hHomeWins = 0, h2hAwayWins = 0, h2hDraws = 0;
    
    final homeTeamId = widget.matchData['homeTeam']['id'];
    final awayTeamId = widget.matchData['awayTeam']['id'];
    
    // Process home team recent matches
    for (var match in _homeTeamRecentMatches) {
      final isHomeGame = match['homeTeam']['id'] == homeTeamId;
      final dynamic rawHomeScore = match['score']?['fullTime']?['home'] ?? 0;
      final dynamic rawAwayScore = match['score']?['fullTime']?['away'] ?? 0;
      
      // Convert scores to int
      final int homeScore = rawHomeScore is num ? rawHomeScore.toInt() : 0;
      final int awayScore = rawAwayScore is num ? rawAwayScore.toInt() : 0;
      
      if (isHomeGame) {
        homeScored += homeScore;
        homeConceded += awayScore;
        
        if (homeScore > awayScore) {
          homeWins++;
        } else if (homeScore < awayScore) {
          homeLosses++;
        } else {
          homeDraws++;
        }
      } else {
        homeScored += awayScore;
        homeConceded += homeScore;
        
        if (awayScore > homeScore) {
          homeWins++;
        } else if (awayScore < homeScore) {
          homeLosses++;
        } else {
          homeDraws++;
        }
      }
    }
    
    // Process away team recent matches
    for (var match in _awayTeamRecentMatches) {
      final isHomeGame = match['homeTeam']['id'] == awayTeamId;
      final dynamic rawHomeScore = match['score']?['fullTime']?['home'] ?? 0;
      final dynamic rawAwayScore = match['score']?['fullTime']?['away'] ?? 0;
      
      // Convert scores to int
      final int homeScore = rawHomeScore is num ? rawHomeScore.toInt() : 0;
      final int awayScore = rawAwayScore is num ? rawAwayScore.toInt() : 0;
      
      if (isHomeGame) {
        awayScored += homeScore;
        awayConceded += awayScore;
        
        if (homeScore > awayScore) {
          awayWins++;
        } else if (homeScore < awayScore) {
          awayLosses++;
        } else {
          awayDraws++;
        }
      } else {
        awayScored += awayScore;
        awayConceded += homeScore;
        
        if (awayScore > homeScore) {
          awayWins++;
        } else if (awayScore < homeScore) {
          awayLosses++;
        } else {
          awayDraws++;
        }
      }
    }
    
    // Process head-to-head matches
    for (var match in _headToHeadMatches) {
      final isHomeTeamHome = match['homeTeam']['id'] == homeTeamId;
      final dynamic rawHomeScore = match['score']?['fullTime']?['home'] ?? 0;
      final dynamic rawAwayScore = match['score']?['fullTime']?['away'] ?? 0;
      
      // Convert scores to int
      final int homeScore = rawHomeScore is num ? rawHomeScore.toInt() : 0;
      final int awayScore = rawAwayScore is num ? rawAwayScore.toInt() : 0;
      
      if (isHomeTeamHome) {
        if (homeScore > awayScore) {
          h2hHomeWins++;
        } else if (homeScore < awayScore) {
          h2hAwayWins++;
        } else {
          h2hDraws++;
        }
      } else {
        if (homeScore < awayScore) {
          h2hHomeWins++;
        } else if (homeScore > awayScore) {
          h2hAwayWins++;
        } else {
          h2hDraws++;
        }
      }
    }
    
    // Update the state variables with calculated stats
    _homeTeamStats = {
      'recent': {'wins': homeWins, 'draws': homeDraws, 'losses': homeLosses},
      'goals': {'scored': homeScored, 'conceded': homeConceded},
    };
    
    _awayTeamStats = {
      'recent': {'wins': awayWins, 'draws': awayDraws, 'losses': awayLosses},
      'goals': {'scored': awayScored, 'conceded': awayConceded},
    };
    
    _h2hStats = {
      'homeWins': h2hHomeWins,
      'awayWins': h2hAwayWins,
      'draws': h2hDraws,
    };
  }

  Widget _buildH2HTab() {
    return _isLoading 
      ? _buildLoadingIndicator() 
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Head to Head summary at the top
              _buildHeadToHeadSummary(),
              
              const SizedBox(height: 24),
              
              // Recent Form section
              _buildSectionTitle('Recent Form'),
              Row(
                children: [
                  Expanded(
                    child: _buildTeamRecentForm(
                      widget.matchData['homeTeam']['name'],
                      _homeTeamStats['recent']['wins'] ?? 0,
                      _homeTeamStats['recent']['draws'] ?? 0,
                      _homeTeamStats['recent']['losses'] ?? 0,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTeamRecentForm(
                      widget.matchData['awayTeam']['name'],
                      _awayTeamStats['recent']['wins'] ?? 0,
                      _awayTeamStats['recent']['draws'] ?? 0,
                      _awayTeamStats['recent']['losses'] ?? 0,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Previous matches between the two teams
              _buildSectionTitle('Previous H2H Matches'),
              _buildH2HMatchesList(),
            ],
          ),
        );
  }

  Widget _buildH2HMatchesList() {
    if (_headToHeadMatches.isEmpty) {
      return const Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No previous matches between these teams',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }
    
    final homeTeamId = widget.matchData['homeTeam']['id'];
    final homeTeamName = widget.matchData['homeTeam']['name'];
    final awayTeamName = widget.matchData['awayTeam']['name'];
    
    return Card(
      elevation: 2,
      child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _headToHeadMatches.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final match = _headToHeadMatches[index];
          final matchHomeTeamId = match['homeTeam']['id'];
          final matchAwayTeamId = match['awayTeam']['id'];
          final matchHomeTeamName = match['homeTeam']['name'] ?? 'Unknown';
          final matchAwayTeamName = match['awayTeam']['name'] ?? 'Unknown';
          final homeScore = match['score']['fullTime']['homeTeam'] ?? 0;
          final awayScore = match['score']['fullTime']['awayTeam'] ?? 0;
          
          // Determine result for home team in this match
          String result;
          Color resultColor;
          
          if (matchHomeTeamId == homeTeamId) {
            if (homeScore > awayScore) {
              result = 'W';
              resultColor = Colors.green;
            } else if (homeScore < awayScore) {
              result = 'L';
              resultColor = Colors.red;
            } else {
              result = 'D';
              resultColor = Colors.orange;
            }
          } else {
            if (homeScore < awayScore) {
              result = 'W';
              resultColor = Colors.green;
            } else if (homeScore > awayScore) {
              result = 'L';
              resultColor = Colors.red;
            } else {
              result = 'D';
              resultColor = Colors.orange;
            }
          }
          
          // Format match date
          String formattedDate = 'Unknown date';
          try {
            if (match['utcDate'] != null) {
              final matchDate = DateTime.parse(match['utcDate']);
              formattedDate = _formatDate(matchDate);
            }
          } catch (e) {
            print('Error formatting date: $e');
          }
          
          // Get competition name
          final competitionName = match['competition']?['name'] ?? 'Unknown';
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: resultColor,
              child: Text(
                result,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Row(
          children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    matchHomeTeamName,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontWeight: matchHomeTeamName == homeTeamName ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    ' $homeScore - $awayScore ',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    matchAwayTeamName,
                    style: TextStyle(
                      fontWeight: matchAwayTeamName == awayTeamName ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Text('$formattedDate • $competitionName'),
          );
        },
      ),
    );
  }

  Widget _buildRecentMatchesTab() {
    return _isLoading 
      ? _buildLoadingIndicator() 
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Home team recent matches
              _buildSectionTitle('${widget.matchData['homeTeam']['name']} Recent Matches'),
              _buildRecentMatches(_homeTeamRecentMatches, widget.matchData['homeTeam']['id']),
              
              const SizedBox(height: 32),
              
              // Away team recent matches
              _buildSectionTitle('${widget.matchData['awayTeam']['name']} Recent Matches'),
              _buildRecentMatches(_awayTeamRecentMatches, widget.matchData['awayTeam']['id']),
            ],
          ),
        );
  }

  Widget _buildDetailedStatsTab() {
    return _isLoading 
      ? _buildLoadingIndicator() 
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display teams names and logos at the top
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      _buildTeamLogo(widget.matchData['homeTeam']['crest'], size: 60),
                      const SizedBox(height: 8),
                      Text(
                        widget.matchData['homeTeam']['name'] ?? 'Home',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const Text(
                    'vs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Column(
                    children: [
                      _buildTeamLogo(widget.matchData['awayTeam']['crest'], size: 60),
                      const SizedBox(height: 8),
                      Text(
                        widget.matchData['awayTeam']['name'] ?? 'Away',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Comprehensive statistics
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // List all available statistics
                      ..._buildAllStatRows(),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Additional stats (cards, fouls, etc.)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cards & Fouls',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Yellow cards
                      _buildCardStatRow(
                        'Yellow Cards',
                        _countCards('YELLOW', widget.matchData['homeTeam']['id']),
                        _countCards('YELLOW', widget.matchData['awayTeam']['id']),
                        cardColor: Colors.yellow,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Red cards
                      _buildCardStatRow(
                        'Red Cards',
                        _countCards('RED', widget.matchData['homeTeam']['id']),
                        _countCards('RED', widget.matchData['awayTeam']['id']),
                        cardColor: Colors.red,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Fouls
                      _buildStatRow(
                        'Fouls',
                        widget.matchData['statistics']?['home_fouls']?.toString() ?? '0',
                        widget.matchData['statistics']?['away_fouls']?.toString() ?? '0',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Additional advanced stats if available
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Advanced Metrics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Expected goals (xG)
                      _buildStatRow(
                        'Expected Goals (xG)',
                        widget.matchData['statistics']?['home_xg']?.toString() ?? '0.00',
                        widget.matchData['statistics']?['away_xg']?.toString() ?? '0.00',
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Aerial duels won
                      _buildStatRow(
                        'Aerial Duels Won',
              widget.matchData['statistics']?['home_aerial_won']?.toString() ?? '0', 
              widget.matchData['statistics']?['away_aerial_won']?.toString() ?? '0', 
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }

  List<Widget> _buildAllStatRows() {
    final statistics = widget.matchData['statistics'] ?? {};
    final statsList = <Widget>[];
    
    // Define all the statistics to display
    final statsToDisplay = [
      {'label': 'Possession', 'homeKey': 'home_possession', 'awayKey': 'away_possession', 'isPercentage': true},
      {'label': 'Shots on Target', 'homeKey': 'home_shots_on_target', 'awayKey': 'away_shots_on_target'},
      {'label': 'Total Shots', 'homeKey': 'home_shots', 'awayKey': 'away_shots'},
      {'label': 'Pass Accuracy', 'homeKey': 'home_pass_accuracy', 'awayKey': 'away_pass_accuracy', 'isPercentage': true},
      {'label': 'Total Passes', 'homeKey': 'home_passes', 'awayKey': 'away_passes'},
      {'label': 'Corners', 'homeKey': 'home_corners', 'awayKey': 'away_corners'},
      {'label': 'Offsides', 'homeKey': 'home_offsides', 'awayKey': 'away_offsides'},
      {'label': 'Blocked Shots', 'homeKey': 'home_blocked_shots', 'awayKey': 'away_blocked_shots'},
    ];
    
    // Build stat rows for each statistic
    for (int i = 0; i < statsToDisplay.length; i++) {
      final stat = statsToDisplay[i];
      final homeValue = statistics[stat['homeKey']]?.toString() ?? '0';
      final awayValue = statistics[stat['awayKey']]?.toString() ?? '0';
      final isPercentage = stat['isPercentage'] == true;
      
      statsList.add(
        _buildStatRow(
          stat['label'] as String,
          homeValue,
          awayValue,
          isPercentage: isPercentage,
        ),
      );
      
      // Add spacing except for the last item
      if (i < statsToDisplay.length - 1) {
        statsList.add(const SizedBox(height: 16));
      }
    }
    
    return statsList;
  }

  Widget _buildCardStatRow(String label, int homeValue, int awayValue, {required Color cardColor}) {
    // Convert values to strings for the stat row
    final homeValueStr = homeValue.toString();
    final awayValueStr = awayValue.toString();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  homeValueStr,
                  style: TextStyle(
                    fontWeight: homeValue > awayValue ? FontWeight.bold : FontWeight.normal,
                    color: homeValue > awayValue ? Colors.blue : null,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 12,
                  height: 16,
        decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 16,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  awayValueStr,
                  style: TextStyle(
                    fontWeight: awayValue > homeValue ? FontWeight.bold : FontWeight.normal,
                    color: awayValue > homeValue ? Colors.blue : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2.5),
          child: SizedBox(
            height: 5,
        child: Row(
          children: [
                // Determine the ratio of cards
                Expanded(
                  flex: homeValue > 0 || awayValue > 0 
                    ? (homeValue * 100 ~/ (homeValue + awayValue)) 
                    : 50,
                  child: Container(
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  flex: homeValue > 0 || awayValue > 0 
                    ? (awayValue * 100 ~/ (homeValue + awayValue)) 
                    : 50,
                  child: Container(
                    color: Colors.red,
                  ),
                ),
          ],
        ),
      ),
        ),
      ],
    );
  }

  int _countCards(String cardType, int teamId) {
    final bookings = widget.matchData['bookings'];
    if (bookings == null || bookings is! List) {
      return 0;
    }
    
    int count = 0;
    for (final booking in bookings) {
      if (booking is Map<String, dynamic> && 
          booking['team']?['id'] == teamId && 
          booking['card'] == cardType) {
        count++;
      }
    }
    
    return count;
  }

  Widget _buildLineupTab() {
    return _isLoading 
      ? _buildLoadingIndicator() 
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              const Text(
                'Starting Lineups',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Team lineups
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Home team lineup
                  Expanded(
                    child: _buildTeamLineup(
                      widget.matchData['homeTeam']['name'],
                      widget.matchData['homeTeam']['formation'],
                      widget.matchData['homeLineup'] ?? [],
                      isHomeTeam: true,
                    ),
                  ),
                  
                  // Away team lineup
                  Expanded(
                    child: _buildTeamLineup(
                      widget.matchData['awayTeam']['name'],
                      widget.matchData['awayTeam']['formation'],
                      widget.matchData['awayLineup'] ?? [],
                      isHomeTeam: false,
                    ),
                  ),
                ],
              ),
              
          const SizedBox(height: 32),
              
              // Substitutes
              const Text(
                'Substitutes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Team substitutes
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Home team subs
                  Expanded(
                    child: _buildTeamSubstitutes(
                      widget.matchData['homeTeam']['name'],
                      widget.matchData['homeBench'] ?? [],
                    ),
                  ),
                  
                  // Away team subs
                  Expanded(
                    child: _buildTeamSubstitutes(
                      widget.matchData['awayTeam']['name'],
                      widget.matchData['awayBench'] ?? [],
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildTeamLineup(String teamName, String? formation, List<dynamic> players, {required bool isHomeTeam}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Team name and formation
            Text(
              teamName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Formation: ${formation ?? 'Unknown'}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            // Players
            if (players.isEmpty)
              const Text(
                'No lineup data available',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              )
            else
              Column(
                crossAxisAlignment: isHomeTeam ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  for (var player in players)
                    if (player is Map<String, dynamic>)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: isHomeTeam ? MainAxisAlignment.start : MainAxisAlignment.end,
                          children: [
                            if (isHomeTeam) ...[
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors['primary']!.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  player['shirtNumber']?.toString() ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: colors['text'],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  player['name'] ?? 'Unknown',
                                  style: TextStyle(color: colors['text']),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: Text(
                                  player['name'] ?? 'Unknown',
                                  style: TextStyle(color: colors['text']),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: colors['primary']!.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  player['shirtNumber']?.toString() ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: colors['text'],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSubstitutes(String teamName, List<dynamic> substitutes) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              teamName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Substitute players
            if (substitutes.isEmpty)
              const Text(
                'No substitute data available',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              )
            else
              for (var sub in substitutes)
                if (sub is Map<String, dynamic>)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: colors['primary']!.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            sub['shirtNumber']?.toString() ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: colors['text'],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sub['name'] ?? 'Unknown',
                            style: TextStyle(color: colors['text'], fontSize: 12),
                            overflow: TextOverflow.ellipsis,
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

  Widget _buildTimelineTab() {
    return _isLoading 
      ? _buildLoadingIndicator() 
      : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match Timeline',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Match events in chronological order
                      _buildMatchTimeline(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildMatchTimeline() {
    final events = _getAllEvents();
    
    if (events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No events recorded for this match yet',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }
    
    // Sort events by minute
    events.sort((a, b) => a['minute'].compareTo(b['minute']));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var event in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event time
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getEventColor(event['type']).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${event['minute']}\'${event['injury'] > 0 ? '+${event['injury']}' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _getEventColor(event['type']),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Event icon
                Icon(
                  _getEventIcon(event['type']),
                  color: _getEventColor(event['type']),
                  size: 24,
                ),
                const SizedBox(width: 12),
                
                // Event details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getEventTitle(event),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _getEventDescription(event),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  List<Map<String, dynamic>> _getAllEvents() {
    final List<Map<String, dynamic>> allEvents = [];
    final homeTeamId = widget.matchData['homeTeam']['id'];
    final awayTeamId = widget.matchData['awayTeam']['id'];
    
    // Add goals
    final goals = _extractGoals();
    for (var goal in goals) {
      allEvents.add({
        'type': 'GOAL',
        'minute': goal['minute'],
        'injury': goal['injuryTime'] ?? 0,
        'playerName': goal['playerName'],
        'playerId': goal['playerId'],
        'teamId': goal['teamId'],
        'teamName': goal['teamName'],
        'isHomeTeam': goal['teamId'] == homeTeamId,
        'isPenalty': goal['isPenalty'],
        'isOwnGoal': goal['isOwnGoal'],
        'assistPlayerName': goal['assistPlayerName'],
        'assistPlayerId': goal['assistPlayerId'],
      });
    }
    
    // Add bookings (yellow and red cards)
    final bookings = widget.matchData['bookings'] ?? [];
    if (bookings is List) {
      for (var booking in bookings) {
        if (booking is Map<String, dynamic>) {
          allEvents.add({
            'type': booking['card'] == 'YELLOW' ? 'YELLOW_CARD' : 'RED_CARD',
            'minute': booking['minute'] ?? 0,
            'injury': booking['injuryTime'] ?? 0,
            'playerName': booking['player']?['name'] ?? 'Unknown Player',
            'playerId': booking['player']?['id'],
            'teamId': booking['team']?['id'],
            'teamName': booking['team']?['name'] ?? 'Unknown Team',
            'isHomeTeam': booking['team']?['id'] == homeTeamId,
            'reason': booking['reason'],
          });
        }
      }
    }
    
    // Add substitutions
    final substitutions = widget.matchData['substitutions'] ?? [];
    if (substitutions is List) {
      for (var sub in substitutions) {
        if (sub is Map<String, dynamic>) {
          allEvents.add({
            'type': 'SUBSTITUTION',
            'minute': sub['minute'] ?? 0,
            'injury': sub['injuryTime'] ?? 0,
            'playerInName': sub['playerIn']?['name'] ?? 'Unknown Player',
            'playerInId': sub['playerIn']?['id'],
            'playerOutName': sub['playerOut']?['name'] ?? 'Unknown Player',
            'playerOutId': sub['playerOut']?['id'],
            'teamId': sub['team']?['id'],
            'teamName': sub['team']?['name'] ?? 'Unknown Team',
            'isHomeTeam': sub['team']?['id'] == homeTeamId,
          });
        }
      }
    }
    
    // Add VAR decisions if available
    final varDecisions = widget.matchData['varDecisions'] ?? [];
    if (varDecisions is List) {
      for (var decision in varDecisions) {
        if (decision is Map<String, dynamic>) {
          allEvents.add({
            'type': 'VAR',
            'minute': decision['minute'] ?? 0,
            'injury': decision['injuryTime'] ?? 0,
            'decision': decision['decision'] ?? 'VAR Check',
            'reason': decision['reason'] ?? 'Unknown reason',
            'teamId': decision['team']?['id'],
            'teamName': decision['team']?['name'] ?? 'Unknown Team',
            'isHomeTeam': decision['team']?['id'] == homeTeamId,
            'playerName': decision['player']?['name'],
          });
        }
      }
    }
    
    // Sort all events by minute and then by injurytime to display them in chronological order
    allEvents.sort((a, b) {
      int minuteComparison = (a['minute'] ?? 0).compareTo(b['minute'] ?? 0);
      if (minuteComparison == 0) {
        return (a['injury'] ?? 0).compareTo(b['injury'] ?? 0);
      }
      return minuteComparison;
    });
    
    return allEvents;
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'GOAL':
        return Icons.sports_soccer;
      case 'YELLOW_CARD':
        return Icons.square_rounded;
      case 'RED_CARD':
        return Icons.square_rounded;
      case 'SUBSTITUTION':
        return Icons.swap_horiz;
      default:
        return Icons.sports;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'GOAL':
        return Colors.green;
      case 'YELLOW_CARD':
        return Colors.amber;
      case 'RED_CARD':
        return Colors.red;
      case 'SUBSTITUTION':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getEventTitle(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'GOAL':
        return '${event['playerName']} scores!';
      case 'YELLOW_CARD':
        return 'Yellow Card: ${event['playerName']}';
      case 'RED_CARD':
        return 'Red Card: ${event['playerName']}';
      case 'SUBSTITUTION':
        return 'Substitution: ${event['teamName']}';
      case 'VAR':
        return 'VAR Decision';
      default:
        return 'Event';
    }
  }

  String _getEventDescription(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'GOAL':
        String description = 'Goal scored by ${event['playerName']} for ${event['teamName']}';
        if (event['isPenalty'] == true) {
          description += ' (Penalty)';
        }
        if (event['isOwnGoal'] == true) {
          description += ' (Own Goal)';
        }
        if (event['assistPlayerName'] != null) {
          description += '\nAssist: ${event['assistPlayerName']}';
        }
        return description;
      case 'YELLOW_CARD':
      case 'RED_CARD':
        return '${event['playerName']} (${event['teamName']})${event['reason'] != null ? ' - ${event['reason']}' : ''}';
      case 'SUBSTITUTION':
        return '${event['playerInName']} comes on for ${event['playerOutName']}';
      case 'VAR':
        String description = event['decision'] ?? 'VAR Check';
        if (event['reason'] != null) {
          description += ' - ${event['reason']}';
        }
        if (event['playerName'] != null) {
          description += '\nPlayer: ${event['playerName']}';
        }
        if (event['teamName'] != null) {
          description += ' (${event['teamName']})';
        }
        return description;
      default:
        return '';
    }
  }

  Widget _buildTimelineSection() {
    final events = _getAllEvents();
    if (events.isEmpty) {
      return const Center(
        child: Text('No match events available'),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Match Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _buildTimelineEvent(event);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEvent(Map<String, dynamic> event) {
    final minute = event['minute'];
    final injury = event['injury'];
    final timeText = injury > 0 ? '$minute+$injury\'' : '$minute\'';
    final isHomeTeam = event['isHomeTeam'] ?? false;

    Widget eventIcon;
    String eventText;
    Color eventColor;

    switch (event['type']) {
      case 'GOAL':
        eventIcon = const Icon(Icons.sports_soccer, size: 20);
        eventColor = Colors.green;
        eventText = _buildGoalText(event);
        break;
      case 'YELLOW_CARD':
        eventIcon = Container(
          width: 12,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.yellow,
            border: Border.all(color: Colors.black12),
          ),
        );
        eventColor = Colors.orange;
        eventText = '${event['playerName']} (${event['teamName']})';
        if (event['reason'] != null) {
          eventText += '\nReason: ${event['reason']}';
        }
        break;
      case 'RED_CARD':
        eventIcon = Container(
          width: 12,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.red,
            border: Border.all(color: Colors.black12),
          ),
        );
        eventColor = Colors.red;
        eventText = '${event['playerName']} (${event['teamName']})';
        if (event['reason'] != null) {
          eventText += '\nReason: ${event['reason']}';
        }
        break;
      case 'SUBSTITUTION':
        eventIcon = const Icon(Icons.swap_horiz, size: 20);
        eventColor = Colors.blue;
        eventText = '${event['playerInName']} ↑\n${event['playerOutName']} ↓\n(${event['teamName']})';
        break;
      case 'VAR':
        eventIcon = const Icon(Icons.tv, size: 20);
        eventColor = Colors.purple;
        eventText = 'VAR Review: ${event['reason']}\n${event['details']}';
        break;
      case 'PENALTY_SCORED':
        eventIcon = const Icon(Icons.sports_soccer, size: 20);
        eventColor = Colors.green;
        eventText = 'Penalty scored by ${event['playerName']} (${event['teamName']})';
        break;
      case 'PENALTY_MISSED':
        eventIcon = const Icon(Icons.sports_soccer, size: 20);
        eventColor = Colors.red;
        eventText = 'Penalty missed by ${event['playerName']} (${event['teamName']})';
        break;
      default:
        eventIcon = const Icon(Icons.sports_soccer, size: 20);
        eventColor = Colors.grey;
        eventText = 'Unknown event';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              timeText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: eventColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  color: eventColor,
                  size: 16,
                ),
                child: eventIcon,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: eventColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: eventColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                eventText,
            style: TextStyle(
                  color: eventColor.withOpacity(0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildGoalText(Map<String, dynamic> goal) {
    final List<String> parts = [];
    
    // Add player name and team
    parts.add('${goal['playerName']} (${goal['teamName']})');
    
    // Add goal type indicators
    if (goal['isOwnGoal'] == true) {
      parts.add('(Own Goal)');
    }
    if (goal['isPenalty'] == true) {
      parts.add('(Penalty)');
    }
    
    // Add assist if available
    if (goal['assistPlayerName'] != null) {
      parts.add('\nAssist: ${goal['assistPlayerName']}');
    }
    
    return parts.join(' ');
  }

  Widget _buildRecentFormSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Form',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Home team form
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.matchData['homeTeam']['name'] ?? 'Home Team',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTeamForm(_homeTeamRecentMatches, widget.matchData['homeTeam']['id']),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Away team form
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.matchData['awayTeam']['name'] ?? 'Away Team',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTeamForm(_awayTeamRecentMatches, widget.matchData['awayTeam']['id']),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamForm(List<dynamic> matches, int teamId) {
    return Row(
      children: matches.take(5).map((match) {
        final isHomeTeam = match['homeTeam']['id'] == teamId;
        final homeScore = match['score']?['fullTime']?['home'] ?? match['score']?['home'] ?? 0;
        final awayScore = match['score']?['fullTime']?['away'] ?? match['score']?['away'] ?? 0;
        
        String result;
        Color color;
        
        if (isHomeTeam) {
          if (homeScore > awayScore) {
            result = 'W';
            color = Colors.green;
          } else if (homeScore < awayScore) {
            result = 'L';
            color = Colors.red;
          } else {
            result = 'D';
            color = Colors.orange;
          }
        } else {
          if (awayScore > homeScore) {
            result = 'W';
            color = Colors.green;
          } else if (awayScore < homeScore) {
            result = 'L';
            color = Colors.red;
          } else {
            result = 'D';
            color = Colors.orange;
          }
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Container(
            width: 24,
            height: 24,
      decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                result,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeadToHeadSection() {
    if (_headToHeadMatches.isEmpty) {
      return const SizedBox.shrink();
    }

    final homeTeamId = widget.matchData['homeTeam']['id'];
    final awayTeamId = widget.matchData['awayTeam']['id'];
    
    int homeWins = 0;
    int awayWins = 0;
    int draws = 0;
    int homeGoals = 0;
    int awayGoals = 0;
    
    for (var match in _headToHeadMatches) {
      final dynamic rawHomeScore = match['score']?['fullTime']?['home'] ?? match['score']?['home'] ?? 0;
      final dynamic rawAwayScore = match['score']?['fullTime']?['away'] ?? match['score']?['away'] ?? 0;
      final int homeScore = rawHomeScore is num ? rawHomeScore.toInt() : 0;
      final int awayScore = rawAwayScore is num ? rawAwayScore.toInt() : 0;
      
      if (match['homeTeam']['id'] == homeTeamId) {
        homeGoals += homeScore;
        awayGoals += awayScore;
        if (homeScore > awayScore) {
          homeWins++;
        } else if (homeScore < awayScore) {
          awayWins++;
        } else {
          draws++;
        }
      } else {
        homeGoals += awayScore;
        awayGoals += homeScore;
        if (awayScore > homeScore) {
          homeWins++;
        } else if (awayScore < homeScore) {
          awayWins++;
        } else {
          draws++;
        }
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
        padding: const EdgeInsets.all(16.0),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text(
              'Head to Head',
                  style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildH2HStat(
                  '${widget.matchData['homeTeam']['name']} wins',
                  homeWins,
                  Colors.blue,
                ),
                _buildH2HStat(
                  'Draws',
                  draws,
                  Colors.orange,
                ),
                _buildH2HStat(
                  '${widget.matchData['awayTeam']['name']} wins',
                  awayWins,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildH2HStat(
                  'Goals scored',
                  homeGoals,
                  Colors.green,
                ),
                _buildH2HStat(
                  'Goals scored',
                  awayGoals,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Recent Meetings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: _headToHeadMatches.take(5).map((match) {
                final date = DateTime.tryParse(match['utcDate'] ?? '');
                final dynamic rawHomeScore = match['score']?['fullTime']?['home'] ?? match['score']?['home'] ?? 0;
                final dynamic rawAwayScore = match['score']?['fullTime']?['away'] ?? match['score']?['away'] ?? 0;
                final int homeScore = rawHomeScore is num ? rawHomeScore.toInt() : 0;
                final int awayScore = rawAwayScore is num ? rawAwayScore.toInt() : 0;
                final isHomeTeamFirst = match['homeTeam']['id'] == homeTeamId;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          date != null ? DateFormat('dd MMM yy').format(date) : '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          isHomeTeamFirst
                              ? '${match['homeTeam']['name']} $homeScore - $awayScore ${match['awayTeam']['name']}'
                              : '${match['homeTeam']['name']} $homeScore - $awayScore ${match['awayTeam']['name']}',
                          style: const TextStyle(
                    fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildH2HStat(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Center(
            child: Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
          label,
          style: const TextStyle(
                    fontSize: 12,
            color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTeamLogo(String? logoUrl, {double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: logoUrl != null
            ? Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.sports_soccer,
                  size: size * 0.5,
                  color: Colors.grey,
                ),
              )
            : Icon(
                Icons.sports_soccer,
                size: size * 0.5,
                color: Colors.grey,
        ),
      ),
    );
  }

  // Generate a team color based on team name
  Color _generateTeamColor(String teamName) {
    // Simple hash function to generate color from team name
    int hash = 0;
    for (var i = 0; i < teamName.length; i++) {
      hash = teamName.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    return Color.fromARGB(
      255,
      ((hash & 0xFF0000) >> 16).abs() % 200 + 55,
      ((hash & 0x00FF00) >> 8).abs() % 200 + 55,
      (hash & 0x0000FF).abs() % 200 + 55,
    );
  }

  // Get the competition name and matchday
  String _getCompetitionName() {
    final competition = widget.matchData['competition']?['name'] ?? 'Unknown Competition';
    final matchday = widget.matchData['matchday'];
    
    if (matchday != null && matchday.toString().isNotEmpty) {
      return '$competition • Matchday $matchday';
    }
    return competition;
  }

  // Get formatted match status and time
  String _getMatchStatusAndTime() {
    final status = widget.matchData['status'] ?? 'UNKNOWN';
    final matchDate = DateTime.tryParse(widget.matchData['utcDate'] ?? '');
    
    switch (status) {
      case 'FINISHED':
        return 'Full Time';
      case 'IN_PLAY':
        return 'Live Now';
      case 'PAUSED':
        return 'Half Time';
      case 'SCHEDULED':
        return matchDate != null 
          ? DateFormat('dd MMM yyyy • HH:mm').format(matchDate.toLocal())
          : 'Scheduled';
      case 'POSTPONED':
        return 'Postponed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  // Display goalscorers in a compact summary
  Widget _buildGoalscorersTextSummary() {
    final goals = _extractGoals();
    if (goals.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final homeTeamId = widget.matchData['homeTeam']['id'];
    final homeGoals = goals.where((goal) => goal['teamId'] == homeTeamId).toList();
    final awayGoals = goals.where((goal) => goal['teamId'] != homeTeamId).toList();
    
    final TextStyle goalScorerStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.normal,
    );
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          // Home team goalscorers
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: homeGoals.map((goal) {
                String scorerText = '${goal['playerName']} ${goal['minute']}\'';
                if (goal['isPenalty'] == true) scorerText += ' (P)';
                if (goal['isOwnGoal'] == true) scorerText += ' (OG)';
                return Text(
                  scorerText,
                  style: goalScorerStyle,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              }).toList(),
            ),
          ),
          
          // Away team goalscorers
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: awayGoals.map((goal) {
                String scorerText = '${goal['minute']}\' ${goal['playerName']}';
                if (goal['isPenalty'] == true) scorerText += ' (P)';
                if (goal['isOwnGoal'] == true) scorerText += ' (OG)';
                return Text(
                  scorerText,
                  style: goalScorerStyle,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Basic tab content methods
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Key stats summary card
          _buildKeyStatsSection(),
          const SizedBox(height: 24),
          
          // Timeline section with events
          _buildTimelineSection(),
          const SizedBox(height: 24),
          
          // Recent form for both teams
          if (_homeTeamRecentMatches.isNotEmpty || _awayTeamRecentMatches.isNotEmpty) ...[
            _buildRecentFormSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKeyStatsSection(),
        ],
      ),
    );
  }


  Widget _buildPlayersTab() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(
          "Player statistics will be displayed here when available",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  // Remove duplicate method declarations and implement missing methods
  Widget _buildH2HSection() {
    if (_headToHeadMatches.isEmpty) {
      return const Center(
        child: Text('No head-to-head data available'),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.matchData['homeTeam']['name']} vs ${widget.matchData['awayTeam']['name']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Head to head matches
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _headToHeadMatches.length,
              itemBuilder: (context, index) {
                final match = _headToHeadMatches[index];
                return _buildMatchItem(match);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Fix conflict by removing the duplicate method declarations for tabs
  // (Delete the duplicate _buildTimelineTab, _buildLineupTab, and _buildH2HTab methods)
  
  // Add missing method for building a match header
  Widget _buildMatchHeader() {
    final homeTeamName = widget.matchData['homeTeam']['name'];
    final awayTeamName = widget.matchData['awayTeam']['name'];
    final homeTeamColor = _generateTeamColor(homeTeamName);
    final awayTeamColor = _generateTeamColor(awayTeamName);
    
    // Extract score
    final score = _extractScore();
    final homeScore = score['homeScore'];
    final awayScore = score['awayScore'];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Competition and matchday
            Text(
              _getCompetitionName(),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            
            // Teams and score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Home team
                Expanded(
                  child: Column(
                    children: [
                      // Home team logo placeholder
                      CircleAvatar(
                        backgroundColor: homeTeamColor.withOpacity(0.2),
                        radius: 30,
                        child: Text(
                          homeTeamName.substring(0, 1),
                          style: TextStyle(
                            color: homeTeamColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Home team name
                      Text(
                        homeTeamName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Score
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Match status
                      Text(
                        _getMatchStatusAndTime(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Score
                      Text(
                        '$homeScore - $awayScore',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Away team
                Expanded(
                  child: Column(
                    children: [
                      // Away team logo placeholder
                      CircleAvatar(
                        backgroundColor: awayTeamColor.withOpacity(0.2),
                        radius: 30,
                        child: Text(
                          awayTeamName.substring(0, 1),
                          style: TextStyle(
                            color: awayTeamColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Away team name
                      Text(
                        awayTeamName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Goalscorers
            const SizedBox(height: 16),
            _buildGoalscorersTextSummary(),
          ],
        ),
      ),
    );
  }

  // Add missing helper methods
  Map<String, dynamic> _extractScore() {
    var homeScore = '0';
    var awayScore = '0';
    
    try {
      final score = widget.matchData['score'];
      if (score != null) {
        // Try to get fullTime score first
        var scoreType = score['fullTime'];
        if (scoreType != null && scoreType['homeTeam'] != null && scoreType['awayTeam'] != null) {
          homeScore = scoreType['homeTeam'].toString();
          awayScore = scoreType['awayTeam'].toString();
        }
        // If fullTime not available, try halfTime
        else if (score['halfTime'] != null && score['halfTime']['homeTeam'] != null && score['halfTime']['awayTeam'] != null) {
          homeScore = score['halfTime']['homeTeam'].toString();
          awayScore = score['halfTime']['awayTeam'].toString();
        }
        // If in penalty shootout
        else if (score['penalties'] != null && score['penalties']['homeTeam'] != null && score['penalties']['awayTeam'] != null) {
          var regularHomeScore = score['extraTime']?['homeTeam'] ?? score['fullTime']?['homeTeam'] ?? 0;
          var regularAwayScore = score['extraTime']?['awayTeam'] ?? score['fullTime']?['awayTeam'] ?? 0;
          homeScore = '$regularHomeScore (${score['penalties']['homeTeam']})';
          awayScore = '$regularAwayScore (${score['penalties']['awayTeam']})';
        }
      }
    } catch (e) {
      print('Error extracting score: $e');
    }
    
    return {
      'homeScore': homeScore,
      'awayScore': awayScore,
    };
  }

  Widget _buildMatchItem(dynamic match) {
    final String homeTeamName = match['homeTeam']?['name'] ?? 'Unknown';
    final String awayTeamName = match['awayTeam']?['name'] ?? 'Unknown';
    
    // Extract score
    var homeScore = '0';
    var awayScore = '0';
    try {
      final score = match['score'];
      if (score != null) {
        var scoreType = score['fullTime'] ?? score['halfTime'];
        if (scoreType != null) {
          homeScore = scoreType['homeTeam']?.toString() ?? '0';
          awayScore = scoreType['awayTeam']?.toString() ?? '0';
        }
      }
    } catch (e) {
      print('Error extracting score for match item: $e');
    }
    
    // Format match date
    final matchDate = DateTime.tryParse(match['utcDate'] ?? '');
    final formattedDate = matchDate != null ? 
        DateFormat('dd MMM yyyy').format(matchDate.toLocal()) : 'Unknown date';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                homeTeamName,
                textAlign: TextAlign.start,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$homeScore - $awayScore',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Text(
                awayTeamName,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}