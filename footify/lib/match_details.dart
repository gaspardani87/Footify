import 'package:flutter/material.dart';
import 'package:footify/theme_provider.dart';

class MatchDetailsPage extends StatelessWidget {
  final Map<String, dynamic> matchData;

  const MatchDetailsPage({Key? key, required this.matchData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMatchHeader(isDarkMode),
            _buildScoreSection(isDarkMode),
            if (matchData['statistics'] != null) _buildMatchStats(isDarkMode),
            _buildMatchTimeline(isDarkMode),
            _buildVenueInfo(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            matchData['competition']?['name'] ?? 'Competition Name Unavailable',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Lexend',
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            matchData['venue']?['name'] ?? 'Venue Information Unavailable',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Lexend',
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection(bool isDarkMode) {
    final homeScore = matchData['score']?['fullTime']?['home']?.toString() ?? 'N/A';
    final awayScore = matchData['score']?['fullTime']?['away']?.toString() ?? 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: Column(
              children: [
                if (matchData['homeTeam']?['crest'] != null)
                  Image.network(
                    matchData['homeTeam']['crest'],
                    height: 60,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_soccer, size: 60),
                  ),
                const SizedBox(height: 8),
                Text(
                  matchData['homeTeam']?['shortName'] ?? matchData['homeTeam']?['name'] ?? 'Unknown Team',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Lexend',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1D1D1B) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$homeScore - $awayScore',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: 'Lexend',
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (matchData['awayTeam']?['crest'] != null)
                  Image.network(
                    matchData['awayTeam']['crest'],
                    height: 60,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_soccer, size: 60),
                  ),
                const SizedBox(height: 8),
                Text(
                  matchData['awayTeam']?['shortName'] ?? matchData['awayTeam']?['name'] ?? 'Unknown Team',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Lexend',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchStats(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Match Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Lexend',
            ),
          ),
          SizedBox(height: 16),
          _buildStatRow('Possession', matchData['statistics']?['home_possession']?.toString() ?? 'N/A', matchData['statistics']?['away_possession']?.toString() ?? 'N/A'),
          _buildStatRow('Shots',  matchData['statistics']?['home_shots']?.toString() ?? 'N/A',  matchData['statistics']?['away_shots']?.toString() ?? 'N/A'),
          _buildStatRow('Shots on Target',  matchData['statistics']?['home_shots_on_target']?.toString() ?? 'N/A', matchData['statistics']?['away_shots_on_target']?.toString() ?? 'N/A'),
          _buildStatRow('Corners',  matchData['statistics']?['home_corners']?.toString() ?? 'N/A', matchData['statistics']?['away_corners']?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String home, String away) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              home,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Lexend',
              ),
            ),
          ),
          SizedBox(width: 16),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontFamily: 'Lexend',
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              away,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'Lexend',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTimeline(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Match Timeline',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Lexend',
            ),
          ),
          SizedBox(height: 16),
          // Timeline items based on match events
        ],
      ),
    );
  }

  Widget _buildVenueInfo(bool isDarkMode) {
    String venueName = matchData['venue']?['name']?.toString() ?? 'Venue information not available';
    String attendance = matchData['attendance']?.toString() ?? 'Attendance not available';

    String refereeName = 'Referee not available';
    if (matchData['referees'] != null && (matchData['referees'] as List).isNotEmpty) {
      refereeName = matchData['referees'][0]?['name']?.toString() ?? 'Referee not available';
    }

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.location_on),
            title: Text(venueName),
            subtitle: Text('Venue'),
          ),
          ListTile(
            leading: Icon(Icons.people),
            title: Text(attendance),
            subtitle: Text('Attendance'),
          ),
          ListTile(
            leading: Icon(Icons.sports),
            title: Text(refereeName),
            subtitle: Text('Referee'),
          ),
        ],
      ),
    );
  }
}