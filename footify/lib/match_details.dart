// match_details.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:footify/theme_provider.dart';
import 'package:footify/color_blind_mode_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:footify/common_layout.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MatchDetailsPage extends StatefulWidget {
  final Map<String, dynamic> matchData;

  const MatchDetailsPage({Key? key, required this.matchData}) : super(key: key);

  @override
  _MatchDetailsPageState createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends State<MatchDetailsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  Map<String, Color> colors = {};
  bool _isLoading = true;
  
  // Variables to store related match data
  List<Map<String, dynamic>> _homeTeamRecentMatches = [];
  List<Map<String, dynamic>> _awayTeamRecentMatches = [];
  List<Map<String, dynamic>> _headToHeadMatches = [];
  
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFFE6AC);
    
    return CommonLayout(
      selectedIndex: 0, // Required parameter
      showBackButton: true, // Enable back button for match details page
      child: Column(
        children: [
          Container(
            height: 45,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _buildTabButton(0, AppLocalizations.of(context)!.stats, isDarkMode, primaryColor),
                        _buildTabButton(1, AppLocalizations.of(context)!.lineups, isDarkMode, primaryColor),
                        _buildTabButton(2, AppLocalizations.of(context)!.timeline, isDarkMode, primaryColor),
                        _buildTabButton(3, "H2H", isDarkMode, primaryColor),
                        _buildTabButton(4, AppLocalizations.of(context)!.detailedStats, isDarkMode, primaryColor),
                        _buildTabButton(5, AppLocalizations.of(context)!.recentMatches, isDarkMode, primaryColor),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 2,
            color: primaryColor,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMatchStatsTab(),
                _buildLineupTab(),
                _buildTimelineTab(),
                _buildH2HTab(),
                _buildDetailedStatsTab(),
                _buildRecentMatchesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabButton(int index, String title, bool isDarkMode, Color primaryColor) {
    bool isSelected = _tabController.index == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? (isDarkMode ? primaryColor : Colors.black)
                : (isDarkMode ? Colors.grey : Colors.grey[600]),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildMatchHeader() {
    final homeTeam = widget.matchData['homeTeam'];
    final awayTeam = widget.matchData['awayTeam'];
    
    // Itt van a probléma - javítsuk ki az eredmény lekérését
    final score = widget.matchData['score'] ?? {};
    final homeGoals = score['fullTime']?['homeTeam'] ?? score['homeTeam'] ?? 0;
    final awayGoals = score['fullTime']?['awayTeam'] ?? score['awayTeam'] ?? 0;
    
    final status = widget.matchData['status'] ?? '';
    final minute = widget.matchData['minute']?.toString() ?? '';
    final injuryTime = widget.matchData['injuryTime'] ?? 0;
    
    // Determine match status text
    String statusText;
    Color statusColor;
    
    if (status == 'IN_PLAY') {
      statusText = '$minute\'${injuryTime > 0 ? '+$injuryTime' : ''}';
      statusColor = Colors.red;
    } else if (status == 'PAUSED') {
      statusText = 'HT';
      statusColor = Colors.orange;
    } else if (status == 'FINISHED') {
      statusText = 'FT';
      statusColor = Colors.green;
    } else if (status == 'POSTPONED') {
      statusText = 'Postponed';
      statusColor = Colors.grey;
    } else {
      statusText = widget.matchData['date'] != null 
        ? '${DateTime.parse(widget.matchData['date']).hour}:${DateTime.parse(widget.matchData['date']).minute}'
        : 'Scheduled';
      statusColor = Colors.grey;
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Match status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Teams and score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Home team
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildTeamLogo(homeTeam['crest'], size: 50),
                      const SizedBox(height: 4),
                      Text(
                        homeTeam['name'] ?? 'Home',
                        style: const TextStyle(
                          fontSize: 14,
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
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: colors['primary']!.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$homeGoals - $awayGoals',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                // Away team
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildTeamLogo(awayTeam['crest'], size: 50),
                      const SizedBox(height: 4),
                      Text(
                        awayTeam['name'] ?? 'Away',
                        style: const TextStyle(
                          fontSize: 14,
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
            
            const SizedBox(height: 16),
            
            // Additional match info (venue, date)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on_outlined, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.matchData['venue'] ?? 'Stadium',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.matchData['date'] != null
                      ? _formatDate(DateTime.parse(widget.matchData['date']))
                      : 'Date not available',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamLogo(String? logoUrl, {double size = 60}) {
    final String? proxyLogoUrl = logoUrl != null ? FootballApiService.getProxyImageUrl(logoUrl) : null;
    
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
        child: proxyLogoUrl != null
            ? Image.network(
                proxyLogoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sports_soccer,
                  size: 30,
                  color: Colors.grey,
                ),
              )
            : const Icon(
                Icons.sports_soccer,
                size: 30,
                color: Colors.grey,
              ),
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
    final goals = widget.matchData['goals'];
    
    if (goals == null || goals is! List) {
      return extractedGoals;
    }
    
    for (final goal in goals) {
      if (goal is Map<String, dynamic>) {
        extractedGoals.add({
          'minute': goal['minute'],
          'playerName': goal['player'],
          'teamId': goal['team']['id'],
          'teamName': goal['team']['name'],
          'isOwnGoal': goal['ownGoal'] ?? false,
          'isPenalty': goal['penalty'] ?? false,
          'assistPlayerName': goal['assist'],
        });
      }
    }
    
    return extractedGoals;
  }

  Widget _buildKeyStatsSection() {
    final statistics = widget.matchData['statistics'] ?? {};
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Key Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Possession
            _buildStatRow(
              'Possession',
              statistics['home_possession']?.toString() ?? '0',
              statistics['away_possession']?.toString() ?? '0',
              isPercentage: true,
            ),
            
            const SizedBox(height: 16),
            
            // Shots on target
            _buildStatRow(
              'Shots on Target',
              statistics['home_shots_on_target']?.toString() ?? '0',
              statistics['away_shots_on_target']?.toString() ?? '0',
            ),
            
            const SizedBox(height: 16),
            
            // Total shots
            _buildStatRow(
              'Total Shots',
              statistics['home_shots']?.toString() ?? '0',
              statistics['away_shots']?.toString() ?? '0',
            ),
            
            const SizedBox(height: 16),
            
            // Pass accuracy
            _buildStatRow(
              'Pass Accuracy',
              statistics['home_pass_accuracy']?.toString() ?? '0',
              statistics['away_pass_accuracy']?.toString() ?? '0',
              isPercentage: true,
            ),
            
            const SizedBox(height: 16),
            
            // Corners
            _buildStatRow(
              'Corners',
              statistics['home_corners']?.toString() ?? '0',
              statistics['away_corners']?.toString() ?? '0',
            ),
          ],
        ),
      ),
    );
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

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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

  Widget _buildRecentMatches(List<Map<String, dynamic>> matches, int teamId) {
    if (matches.isEmpty) {
      return const Text('No recent matches found');
    }
    
    return Card(
      elevation: 2,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: matches.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          try {
            final match = matches[index];
            final homeTeamId = match['homeTeam']['id'];
            final awayTeamId = match['awayTeam']['id'];
            final homeTeamName = match['homeTeam']['name'] ?? 'Unknown';
            final awayTeamName = match['awayTeam']['name'] ?? 'Unknown';
            final homeScore = match['score']['fullTime']['homeTeam'] ?? 0;
            final awayScore = match['score']['fullTime']['awayTeam'] ?? 0;
            
            // Determine if the team of interest won, lost, or drew
            String result;
            Color resultColor;
            
            if (homeTeamId == teamId) {
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
            
            String formattedDate = 'Unknown date';
            try {
              if (match['utcDate'] != null) {
                final matchDate = DateTime.parse(match['utcDate']);
                formattedDate = '${matchDate.day}/${matchDate.month}/${matchDate.year}';
              }
            } catch (e) {
              print('Error formatting date: $e');
            }
            
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
                      homeTeamName,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: homeTeamId == teamId ? FontWeight.bold : FontWeight.normal,
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
                      awayTeamName,
                      style: TextStyle(
                        fontWeight: awayTeamId == teamId ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: Text(formattedDate),
            );
          } catch (e) {
            print('Error rendering match at index $index: $e');
            return const ListTile(
              title: Text('Error displaying match'),
              subtitle: Text('Unable to load match data'),
            );
          }
        },
      ),
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
      final match = widget.matchData;
      final homeTeamId = match['homeTeam']['id'];
      final awayTeamId = match['awayTeam']['id'];
      
      // Fetch both teams' recent matches (last 5)
      final DateTime today = DateTime.now();
      final String dateTo = today.toIso8601String().split('T')[0];
      final String dateFrom = DateTime(today.year - 1, today.month, today.day)
          .toIso8601String()
          .split('T')[0];
          
      // Use try-catch for each API call separately to handle individual failures
      try {
        // Fetch home team matches
        final homeTeamMatchesResponse = await FootballApiService.getTeamMatches(
          homeTeamId,
          status: 'FINISHED',
          dateFrom: dateFrom,
          dateTo: dateTo,
          limit: 5
        );
        
        if (mounted) {
          setState(() {
            _homeTeamRecentMatches = (homeTeamMatchesResponse['matches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          });
        }
      } catch (e) {
        print('Error fetching home team matches: $e');
      }
      
      try {
        // Fetch away team matches
        final awayTeamMatchesResponse = await FootballApiService.getTeamMatches(
          awayTeamId,
          status: 'FINISHED',
          dateFrom: dateFrom,
          dateTo: dateTo,
          limit: 5
        );
        
        if (mounted) {
          setState(() {
            _awayTeamRecentMatches = (awayTeamMatchesResponse['matches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          });
        }
      } catch (e) {
        print('Error fetching away team matches: $e');
      }
      
      try {
        // Fetch head-to-head matches
        final h2hMatchesResponse = await FootballApiService.getTeamMatches(
          homeTeamId,
          status: 'FINISHED',
          dateFrom: dateFrom,
          dateTo: dateTo,
          limit: 10
        );
        
        if (mounted && h2hMatchesResponse['matches'] != null) {
          // Filter h2h matches to only include those between these two teams
          final List<dynamic> allH2hMatches = h2hMatchesResponse['matches'] ?? [];
          final List<dynamic> h2hMatches = allH2hMatches.where((m) => 
            (m['homeTeam']['id'] == homeTeamId && m['awayTeam']['id'] == awayTeamId) ||
            (m['homeTeam']['id'] == awayTeamId && m['awayTeam']['id'] == homeTeamId)
          ).toList();
          
          setState(() {
            _headToHeadMatches = h2hMatches.cast<Map<String, dynamic>>();
          });
        }
      } catch (e) {
        print('Error fetching head-to-head matches: $e');
      }
      
      // Calculate stats once we have all the data
      if (mounted) {
        setState(() {
          _calculateStats();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _fetchRelatedMatchData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add a method to calculate stats based on recent matches
  void _calculateStats() {
    try {
      // Home team stats
      int homeWins = 0, homeDraws = 0, homeLosses = 0, homeScored = 0, homeConceded = 0;
      
      for (final match in _homeTeamRecentMatches) {
        try {
          final bool isHomeTeam = match['homeTeam']['id'] == widget.matchData['homeTeam']['id'];
          final int goalsFor = isHomeTeam 
            ? (match['score']['fullTime']['homeTeam'] ?? 0) 
            : (match['score']['fullTime']['awayTeam'] ?? 0);
          final int goalsAgainst = isHomeTeam 
            ? (match['score']['fullTime']['awayTeam'] ?? 0) 
            : (match['score']['fullTime']['homeTeam'] ?? 0);
          
          homeScored += goalsFor;
          homeConceded += goalsAgainst;
          
          if (goalsFor > goalsAgainst) {
            homeWins++;
          } else if (goalsFor < goalsAgainst) {
            homeLosses++;
          } else {
            homeDraws++;
          }
        } catch (e) {
          print('Error processing home team match: $e');
        }
      }
      
      // Away team stats
      int awayWins = 0, awayDraws = 0, awayLosses = 0, awayScored = 0, awayConceded = 0;
      
      for (final match in _awayTeamRecentMatches) {
        try {
          final bool isHomeTeam = match['homeTeam']['id'] == widget.matchData['awayTeam']['id'];
          final int goalsFor = isHomeTeam 
            ? (match['score']['fullTime']['homeTeam'] ?? 0) 
            : (match['score']['fullTime']['awayTeam'] ?? 0);
          final int goalsAgainst = isHomeTeam 
            ? (match['score']['fullTime']['awayTeam'] ?? 0) 
            : (match['score']['fullTime']['homeTeam'] ?? 0);
          
          awayScored += goalsFor;
          awayConceded += goalsAgainst;
          
          if (goalsFor > goalsAgainst) {
            awayWins++;
          } else if (goalsFor < goalsAgainst) {
            awayLosses++;
          } else {
            awayDraws++;
          }
        } catch (e) {
          print('Error processing away team match: $e');
        }
      }
      
      // Head to head stats
      int h2hHomeWins = 0, h2hAwayWins = 0, h2hDraws = 0;
      
      for (final match in _headToHeadMatches) {
        try {
          final int homeTeamId = match['homeTeam']['id'];
          final int awayTeamId = match['awayTeam']['id'];
          final int homeGoals = match['score']['fullTime']['homeTeam'] ?? 0;
          final int awayGoals = match['score']['fullTime']['awayTeam'] ?? 0;
          
          if (homeGoals > awayGoals) {
            if (homeTeamId == widget.matchData['homeTeam']['id']) {
              h2hHomeWins++;
            } else {
              h2hAwayWins++;
            }
          } else if (homeGoals < awayGoals) {
            if (awayTeamId == widget.matchData['homeTeam']['id']) {
              h2hHomeWins++;
            } else {
              h2hAwayWins++;
            }
          } else {
            h2hDraws++;
          }
        } catch (e) {
          print('Error processing head-to-head match: $e');
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
    } catch (e) {
      print('Error in _calculateStats: $e');
    }
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
                    '${event['minute']}\'' + (event['injury'] > 0 ? '+${event['injury']}' : ''),
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
    
    // Add goals
    final goals = _extractGoals();
    for (var goal in goals) {
      allEvents.add({
        'type': 'GOAL',
        'minute': goal['minute'],
        'injury': goal['injuryTime'] ?? 0,
        'playerId': goal['playerId'],
        'playerName': goal['playerName'],
        'teamId': goal['teamId'],
        'teamName': goal['teamName'],
        'isPenalty': goal['isPenalty'],
        'isOwnGoal': goal['isOwnGoal'],
      });
    }
    
    // Add bookings (yellow and red cards)
    final bookings = widget.matchData['bookings'];
    if (bookings != null && bookings is List) {
      for (var booking in bookings) {
        if (booking is Map<String, dynamic>) {
          allEvents.add({
            'type': booking['card'] == 'YELLOW' ? 'YELLOW_CARD' : 'RED_CARD',
            'minute': booking['minute'],
            'injury': booking['injuryTime'] ?? 0,
            'playerId': booking['player']['id'],
            'playerName': booking['player']['name'],
            'teamId': booking['team']['id'],
            'teamName': booking['team']['name'],
            'reason': booking['reason'],
          });
        }
      }
    }
    
    // Add substitutions
    final substitutions = widget.matchData['substitutions'];
    if (substitutions != null && substitutions is List) {
      for (var sub in substitutions) {
        if (sub is Map<String, dynamic>) {
          allEvents.add({
            'type': 'SUBSTITUTION',
            'minute': sub['minute'],
            'injury': sub['injuryTime'] ?? 0,
            'playerInId': sub['playerIn']['id'],
            'playerInName': sub['playerIn']['name'],
            'playerOutId': sub['playerOut']['id'],
            'playerOutName': sub['playerOut']['name'],
            'teamId': sub['team']['id'],
            'teamName': sub['team']['name'],
          });
        }
      }
    }
    
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
        return description;
      case 'YELLOW_CARD':
      case 'RED_CARD':
        return '${event['playerName']} (${event['teamName']})${event['reason'] != null ? ' - ${event['reason']}' : ''}';
      case 'SUBSTITUTION':
        return '${event['playerInName']} comes on for ${event['playerOutName']}';
      default:
        return '';
    }
  }
}

// Add the FootballApiService class
class FootballApiService {
  // Base URL for Firebase Functions
  static String baseUrl = '';
  static bool _initialized = false;

  // Initialize the service with your Firebase project ID
  static void initialize(String firebaseProjectId) {
    baseUrl = 'https://us-central1-$firebaseProjectId.cloudfunctions.net';
    _initialized = true;
  }

  // Check if service is initialized before making API calls
  static void _checkInitialized() {
    if (!_initialized) {
      throw Exception('FootballApiService has not been initialized. Call initialize(firebaseProjectId) first.');
    }
  }
  
  // Get all matches
  static Future<Map<String, dynamic>> getMatches() async {
    _checkInitialized();
    try {
      final response = await http.get(Uri.parse('$baseUrl/fetchFootballData'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load matches: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching matches: $e');
    }
  }
  
  // Get specific match by ID
  static Future<Map<String, dynamic>> getMatchById(int matchId) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fetchMatchById').replace(
          queryParameters: {'id': matchId.toString()}
        )
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load match: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching match: $e');
    }
  }
  
  // Get competitions
  static Future<Map<String, dynamic>> getCompetitions() async {
    _checkInitialized();
    try {
      final response = await http.get(Uri.parse('$baseUrl/fetchCompetitions'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load competitions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching competitions: $e');
    }
  }
  
  // Get specific competition by code
  static Future<Map<String, dynamic>> getCompetitionByCode(String code) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fetchCompetitionByCode').replace(
          queryParameters: {'code': code}
        )
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load competition: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching competition: $e');
    }
  }
  
  // Get standings for a competition
  static Future<Map<String, dynamic>> getStandings(String competitionCode) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fetchStandings').replace(
          queryParameters: {'code': competitionCode}
        )
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load standings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching standings: $e');
    }
  }
  
  // Get team details
  static Future<Map<String, dynamic>> getTeam(int teamId) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fetchTeam').replace(
          queryParameters: {'id': teamId.toString()}
        )
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load team: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching team: $e');
    }
  }
  
  // Get matches for a team
  static Future<Map<String, dynamic>> getTeamMatches(
    int teamId, {
    String? status,
    String? dateFrom,
    String? dateTo,
    int limit = 10
  }) async {
    _checkInitialized();
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
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load team matches: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching team matches: $e');
    }
  }
  
  // Get player details
  static Future<Map<String, dynamic>> getPlayer(int playerId) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fetchPlayer').replace(
          queryParameters: {'id': playerId.toString()}
        )
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load player: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching player: $e');
    }
  }
  
  // Get proxied image URL
  static String getProxyImageUrl(String originalUrl) {
    _checkInitialized();
    return '$baseUrl/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
  }
}

class _PlayerCircle extends StatelessWidget {
  final Map<String, Color> colors;

  const _PlayerCircle({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors['surface'],
        shape: BoxShape.circle,
        border: Border.all(color: colors['primary']!, width: 2),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final Map<String, Color> colors;
  final VoidCallback? onTap;

  const _PlayerTile({
    required this.player,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 100,
        maxWidth: 120,
        minHeight: 80,
        maxHeight: 100,
      ),
      child: Material(
        color: colors['surface'],
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  player['shirtNumber']?.toString() ?? '',
                  style: TextStyle(
                    color: colors['textSecondary'],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player['name'] ?? '',
                  style: TextStyle(
                    color: colors['text'],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((player['goals'] ?? 0) > 0 || (player['yellowCards'] ?? 0) > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((player['goals'] ?? 0) > 0)
                        const Icon(Icons.sports_soccer, color: Colors.green, size: 16),
                      if ((player['yellowCards'] ?? 0) > 0)
                        const Icon(Icons.warning_amber, color: Colors.yellow, size: 16),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}