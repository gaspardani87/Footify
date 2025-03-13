// match_details.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:footify/theme_provider.dart';
import 'package:footify/color_blind_mode_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MatchDetailsPage extends StatefulWidget {
  final Map<String, dynamic> matchData;

  const MatchDetailsPage({Key? key, required this.matchData}) : super(key: key);

  @override
  _MatchDetailsPageState createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends State<MatchDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _tabs;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Fix length to match number of tabs
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabs = [
      AppLocalizations.of(context)!.stats,
      AppLocalizations.of(context)!.lineups,
      AppLocalizations.of(context)!.timeline,
      AppLocalizations.of(context)!.h2h,
      AppLocalizations.of(context)!.detailedStats,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorBlindMode = Provider.of<ColorBlindModeProvider>(context).isColorBlindMode;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = _getColors(themeProvider, colorBlindMode, isDarkMode);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.matchDetails),
        bottom: _buildTabBar(colors),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => _tabController.animateTo(index),
        children: [
          _buildStatsTab(colors),
          _buildLineupsTab(colors),
          //_buildTimelineTab(colors),
          //_buildH2HTab(colors),
          //_buildDetailedStatsTab(colors),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTabBar(Map<String, Color> colors) {
    return PreferredSize(
      preferredSize: Size.fromHeight(48),
      child: Container(
        color: colors['background'],
        child: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          isScrollable: true,
          indicatorColor: colors['primary'],
          labelColor: colors['primary'],
          unselectedLabelColor: colors['textSecondary'],
          onTap: (index) => _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsTab(Map<String, Color> colors) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          //_buildScoreSummary(colors),
          SizedBox(height: 24),
          _buildComparisonRow(
            AppLocalizations.of(context)!.possession,
            widget.matchData['statistics']?['home_possession'] ?? 0,
            widget.matchData['statistics']?['away_possession'] ?? 0,
            colors,
          ),
          _buildComparisonRow(
            AppLocalizations.of(context)!.shotsOnTarget,
            widget.matchData['statistics']?['home_shots_on_target'] ?? 0,
            widget.matchData['statistics']?['away_shots_on_target'] ?? 0,
            colors,
          ),
          // Add more comparison rows
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, int homeValue, int awayValue, Map<String, Color> colors) {
    final total = homeValue + awayValue;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$homeValue', style: TextStyle(color: colors['text'])),
              Text(label, style: TextStyle(color: colors['textSecondary'])),
              Text('$awayValue', style: TextStyle(color: colors['text'])),
            ],
          ),
          SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: colors['surface'],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedFractionallySizedBox(
                widthFactor: total == 0 ? 0.5 : homeValue / total,
                heightFactor: 1,
                duration: Duration(milliseconds: 500),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors['primary'],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineupsTab(Map<String, Color> colors) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFormationView(widget.matchData['homeTeam'], colors),
          SizedBox(height: 32),
          _buildFormationView(widget.matchData['awayTeam'], colors),
        ],
      ),
    );
  }

  Widget _buildFormationView(Map<String, dynamic> team, Map<String, Color> colors) {
    final formation = team['formation']?.split('-') ?? [4, 4, 2];
    return Column(
      children: [
        Text(team['name'], style: TextStyle(
          color: colors['text'],
          fontSize: 20,
          fontWeight: FontWeight.bold,
        )),
        SizedBox(height: 16),
        // Formation visualization
        Column(
          children: formation.reversed.map((row) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(int.parse(row), (_) => _PlayerCircle(colors: colors)),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (team['lineup'] as List).map<Widget>((player) {
            return _PlayerTile(
              player: player,
              colors: colors,
              onTap: () => _showPlayerDetails(player, colors)
            );
          }).toList(),
        ),
      ],
    );
  }

  // Add other tab builders (_buildTimelineTab, _buildH2HTab, _buildDetailedStatsTab)
  // Implement remaining UI components and functionality

  Map<String, Color> _getColors(ThemeProvider theme, bool colorBlind, bool isDark) {
    if (isDark) {
      return colorBlind ? {
        'background': const Color(0xFF1A1A2F),
        'surface': const Color(0xFF2A2A4A),
        'primary': const Color(0xFFF4D03F),
        'text': const Color(0xFFF9E79F),
        'textSecondary': const Color(0xFFF7DC6F),
      } : {
        'background': const Color(0xFF1D1D1D),
        'surface': const Color(0xFF292929),
        'primary': const Color(0xFFFFE6AC),
        'text': Colors.white,
        'textSecondary': Colors.grey,
      };
    } else {
      return colorBlind ? {
        'background': const Color(0xFFF8F9FA),
        'surface': const Color(0xFFE9ECEF),
        'primary': const Color(0xFF2E86C1),
        'text': const Color(0xFF2C3E50),
        'textSecondary': const Color(0xFF566573),
      } : {
        'background': Colors.white,
        'surface': Colors.grey[50]!,
        'primary': const Color(0xFFFFE6AC),
        'text': Colors.black,
        'textSecondary': Colors.black54,
      };
    }
  }

  void _showPlayerDetails(Map<String, dynamic> player, Map<String, Color> colors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors['surface'],
        title: Text(
          player['name'],
          style: TextStyle(color: colors['text']),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shirt Number: ${player['shirtNumber']}',
              style: TextStyle(color: colors['text']),
            ),
            if (player['position'] != null) Text(
              'Position: ${player['position']}',
              style: TextStyle(color: colors['text']),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
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
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors['surface'],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              player['shirtNumber']?.toString() ?? '',
              style: TextStyle(color: colors['textSecondary']),
            ),
            Text(
              player['name'] ?? '',
              style: TextStyle(color: colors['text']),
              overflow: TextOverflow.ellipsis,
            ),
            if ((player['goals'] ?? 0) > 0)
              Icon(Icons.sports_soccer, color: Colors.green, size: 16),
            if ((player['yellowCards'] ?? 0) > 0)
              Icon(Icons.warning_amber, color: Colors.yellow, size: 16),
          ],
        ),
      ),
    );
  }
}