import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Match model for last matches
class Match {
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final int homeScore;
  final int awayScore;
  final DateTime date;

  Match({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTeamLogo,
    required this.awayTeamLogo,
    required this.homeScore,
    required this.awayScore,
    required this.date,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      homeTeam: json['homeTeam']['name'] ?? 'Unknown',
      awayTeam: json['awayTeam']['name'] ?? 'Unknown',
      homeTeamLogo: json['homeTeam']['crest'],
      awayTeamLogo: json['awayTeam']['crest'],
      homeScore: json['score']['fullTime']['home'] ?? 0,
      awayScore: json['score']['fullTime']['away'] ?? 0,
      date: DateTime.parse(json['utcDate']),
    );
  }
}

// Csapat modell a tabellához
class TeamStanding {
  final int position;
  final String teamName;
  final String? teamLogo;
  final int playedGames;
  final int points;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  TeamStanding({
    required this.position,
    required this.teamName,
    required this.teamLogo,
    required this.playedGames,
    required this.points,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  factory TeamStanding.fromJson(Map<String, dynamic> json) {
    return TeamStanding(
      position: json['position'] ?? 0,
      teamName: json['team']['name'] ?? 'Ismeretlen csapat',
      teamLogo: json['team']['crest'],
      playedGames: json['playedGames'] ?? 0,
      points: json['points'] ?? 0,
      won: json['won'] ?? 0,
      draw: json['draw'] ?? 0,
      lost: json['lost'] ?? 0,
      goalsFor: json['goalsFor'] ?? 0,
      goalsAgainst: json['goalsAgainst'] ?? 0,
    );
  }
}

class LeagueDetailsPage extends StatefulWidget {
  final int leagueId;
  final String leagueName;

  const LeagueDetailsPage({super.key, required this.leagueId, required this.leagueName});

  @override
  State<LeagueDetailsPage> createState() => _LeagueDetailsPageState();
}

class _LeagueDetailsPageState extends State<LeagueDetailsPage> {
  late Future<List<TeamStanding>> futureStandings;
  late Future<List<Match>> futureLastMatches;
  bool isWideScreen = false;

  @override
  void initState() {
    super.initState();
    futureStandings = fetchStandings(widget.leagueId);
    futureLastMatches = fetchLastRoundMatches(widget.leagueId);
  }

  Future<List<Match>> fetchLastRoundMatches(int leagueId) async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-footify-13da4.cloudfunctions.net/fetchLastRoundMatches?id=$leagueId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> matches = data['matches'];
        return matches.map((match) => Match.fromJson(match)).toList();
      } else {
        throw Exception('Failed to load last matches');
      }
    } catch (e) {
      print('Error fetching last matches: $e');
      return [];
    }
  }

  Future<List<TeamStanding>> fetchStandings(int leagueId) async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-footify-13da4.cloudfunctions.net/fetchLeagueStandings?id=$leagueId'),
      );

      if (response.statusCode == 200) {
        List<dynamic> standings = jsonDecode(response.body)['standings'][0]['table'];
        return standings.map((team) => TeamStanding.fromJson(team)).toList();
      } else {
        throw Exception('Nem sikerült betölteni a tabellát');
      }
    } catch (e) {
      print('Error fetching standings: $e');
      throw Exception('Nem sikerült betölteni a tabellát');
    }
  }

  Color getPositionColor(int position, int leagueId) {
    // Premier League
    if (leagueId == 2021) {
      if (position <= 4) return Colors.blue; // Champions League
      if (position <= 6) return Colors.orange; // Europa League
      if (position >= 18) return Colors.red; // Relegation
    }
    // La Liga
    else if (leagueId == 2014) {
      if (position <= 4) return Colors.blue; // Champions League
      if (position <= 6) return Colors.orange; // Europa League
      if (position >= 18) return Colors.red; // Relegation
    }
    // Bundesliga
    else if (leagueId == 2002) {
      if (position <= 4) return Colors.blue; // Champions League
      if (position <= 6) return Colors.orange; // Europa League
      if (position >= 16) return Colors.red; // Relegation
    }
    // Serie A
    else if (leagueId == 2019) {
      if (position <= 4) return Colors.blue; // Champions League
      if (position <= 6) return Colors.orange; // Europa League
      if (position >= 18) return Colors.red; // Relegation
    }
    // Ligue 1
    else if (leagueId == 2015) {
      if (position <= 2) return Colors.blue; // Champions League
      if (position <= 4) return Colors.orange; // Europa League
      if (position >= 18) return Colors.red; // Relegation
    }
    // Championship (Promotion)
    else if (leagueId == 2016) {
      if (position <= 2) return Colors.green; // Automatic promotion
      if (position <= 6) return Colors.orange; // Play-off promotion
      if (position >= 22) return Colors.red; // Relegation
    }
    // League One (Promotion)
    else if (leagueId == 2017) {
      if (position <= 2) return Colors.green; // Automatic promotion
      if (position <= 6) return Colors.orange; // Play-off promotion
      if (position >= 21) return Colors.red; // Relegation
    }
    return Colors.transparent;
  }

  String getLeagueQualificationText(int leagueId) {
    switch (leagueId) {
      case 2021: // Premier League
        return 'Top 4: Champions League\n5-6: Europa League\n18-20: Relegation';
      case 2014: // La Liga
        return 'Top 4: Champions League\n5-6: Europa League\n18-20: Relegation';
      case 2002: // Bundesliga
        return 'Top 4: Champions League\n5-6: Europa League\n16-18: Relegation';
      case 2019: // Serie A
        return 'Top 4: Champions League\n5-6: Europa League\n18-20: Relegation';
      case 2015: // Ligue 1
        return 'Top 2: Champions League\n3-4: Europa League\n18-20: Relegation';
      case 2016: // Championship
        return 'Top 2: Automatic Promotion\n3-6: Play-off Promotion\n22-24: Relegation';
      case 2017: // League One
        return 'Top 2: Automatic Promotion\n3-6: Play-off Promotion\n21-24: Relegation';
      default:
        return '';
    }
  }

  List<Map<String, dynamic>> getRelevantColors(int leagueId) {
    switch (leagueId) {
      case 2021: // Premier League
      case 2014: // La Liga
      case 2019: // Serie A
      case 2002: // Bundesliga
        return [
          {'color': Colors.blue, 'name': 'Bajnokok Ligája'},
          {'color': Colors.orange, 'name': 'Európa Liga'},
          {'color': Colors.red, 'name': 'Kiesés'},
        ];
      case 2015: // Ligue 1
        return [
          {'color': Colors.blue, 'name': 'Bajnokok Ligája'},
          {'color': Colors.orange, 'name': 'Európa Liga'},
          {'color': Colors.red, 'name': 'Kiesés'},
        ];
      case 2016: // Championship
      case 2017: // League One
        return [
          {'color': Colors.green, 'name': 'Feljutás'},
          {'color': Colors.orange, 'name': 'Rájátszás'},
          {'color': Colors.red, 'name': 'Kiesés'},
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.leagueName),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Tabella',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                  ),
                ),
                FutureBuilder<List<TeamStanding>>(
                  future: futureStandings,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Hiba: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Nincs elérhető adat'));
                    }

                    return isWideScreen
                        ? _buildWideLayout(snapshot.data!, isDarkMode)
                        : _buildNarrowLayout(snapshot.data!, isDarkMode);
                  },
                ),
                _buildLegend(isDarkMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(List<TeamStanding> standings, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildLastMatches(isDarkMode),
        ),
        Expanded(
          flex: 3,
          child: _buildStandingsTable(standings, isDarkMode),
        ),
        Expanded(
          flex: 2,
          child: _buildLastMatches(isDarkMode),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(List<TeamStanding> standings, bool isDarkMode) {
    return Column(
      children: [
        _buildStandingsTable(standings, isDarkMode),
        const SizedBox(height: 16),
        _buildLastMatches(isDarkMode),
      ],
    );
  }

  Widget _buildLastMatches(bool isDarkMode) {
    return FutureBuilder<List<Match>>(
      future: futureLastMatches,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Hiba: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nincs elérhető mérkőzés'));
        }

        return Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Utolsó forduló',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final match = snapshot.data![index];
                  return _buildMatchCard(match, isDarkMode);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchCard(Match match, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildTeamLogo(match.homeTeamLogo, isDarkMode),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    match.homeTeam,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${match.homeScore} - ${match.awayScore}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    match.awayTeam,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildTeamLogo(match.awayTeamLogo, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(String? logoUrl, bool isDarkMode) {
    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.white,
        shape: BoxShape.circle,
      ),
      child: logoUrl != null
          ? Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.sports_soccer, size: 16);
              },
            )
          : const Icon(Icons.sports_soccer, size: 16),
    );
  }

  Widget _buildStandingsTable(List<TeamStanding> standings, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 56,
          columnSpacing: 24,
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          dataTextStyle: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          dividerThickness: 0,
          columns: [
            const DataColumn(label: SizedBox(width: 4)), // Color indicator column
            const DataColumn(label: Text('#')),
            const DataColumn(label: Text('Csapat')),
            const DataColumn(label: Text('M')),
            const DataColumn(label: Text('GY')),
            const DataColumn(label: Text('D')),
            const DataColumn(label: Text('V')),
            if (isWideScreen) ...[
              const DataColumn(label: Text('G+')),
              const DataColumn(label: Text('G-')),
            ],
            const DataColumn(label: Text('GK')),
            const DataColumn(label: Text('P')),
          ],
          rows: standings.map((team) {
            final positionColor = getPositionColor(team.position, widget.leagueId);
            return DataRow(
              cells: [
                DataCell(
                  Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: positionColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
                DataCell(Text(team.position.toString())),
                DataCell(
                  SizedBox(
                    width: 160,
                    child: Row(
                      children: [
                        team.teamLogo != null
                          ? Container(
                              width: 32,
                              height: 32,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Image.network(
                                team.teamLogo!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.sports_soccer, size: 20);
                                },
                              ),
                            )
                          : Container(
                              width: 32,
                              height: 32,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.sports_soccer, size: 20),
                            ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            team.teamName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(team.playedGames.toString())),
                DataCell(Text(team.won.toString())),
                DataCell(Text(team.draw.toString())),
                DataCell(Text(team.lost.toString())),
                if (isWideScreen) ...[
                  DataCell(Text(team.goalsFor.toString())),
                  DataCell(Text(team.goalsAgainst.toString())),
                ],
                DataCell(Text((team.goalsFor - team.goalsAgainst).toString())),
                DataCell(Text(
                  team.points.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegend(bool isDarkMode) {
    final relevantColors = getRelevantColors(widget.leagueId);
    if (relevantColors.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: relevantColors.map((colorInfo) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colorInfo['color'],
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorInfo['color'].withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                colorInfo['name'],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
} 