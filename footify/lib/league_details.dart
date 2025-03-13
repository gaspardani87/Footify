import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    futureStandings = fetchStandings(widget.leagueId);
  }

  Future<List<TeamStanding>> fetchStandings(int leagueId) async {
    // Itt kell az API-hoz csatlakozni a bajnokság tabellájának lekéréséhez
    // Példa implementáció:
    final response = await http.get(
      Uri.parse('https://api.football-data.org/v4/competitions/$leagueId/standings'),
      headers: {'X-Auth-Token': '4c553fac5d704101906782d1ecbe1b12'},
    );

    if (response.statusCode == 200) {
      List<dynamic> standings = jsonDecode(response.body)['standings'][0]['table'];
      return standings.map((team) => TeamStanding.fromJson(team)).toList();
    } else {
      throw Exception('Nem sikerült betölteni a tabellát');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.leagueName),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
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
              Expanded(
                child: FutureBuilder<List<TeamStanding>>(
                  future: futureStandings,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Hiba: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Nincs elérhető adat'));
                    }

                    return _buildStandingsTable(snapshot.data!, isDarkMode);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandingsTable(List<TeamStanding> standings, bool isDarkMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 40,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 48,
          columnSpacing: 16,
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          dataTextStyle: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('Csapat')),
            DataColumn(label: Text('M')),
            DataColumn(label: Text('GY')),
            DataColumn(label: Text('D')),
            DataColumn(label: Text('V')),
            DataColumn(label: Text('G+')),
            DataColumn(label: Text('G-')),
            DataColumn(label: Text('GK')),
            DataColumn(label: Text('P')),
          ],
          rows: standings.map((team) {
            return DataRow(
              cells: [
                DataCell(Text(team.position.toString())),
                DataCell(
                  SizedBox(
                    width: 130,
                    child: Row(
                      children: [
                        team.teamLogo != null
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: Image.network(
                                team.teamLogo!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.sports_soccer, size: 20);
                                },
                              ),
                            )
                          : const Icon(Icons.sports_soccer, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            team.teamName,
                            overflow: TextOverflow.ellipsis,
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
                DataCell(Text(team.goalsFor.toString())),
                DataCell(Text(team.goalsAgainst.toString())),
                DataCell(Text((team.goalsFor - team.goalsAgainst).toString())),
                DataCell(Text(team.points.toString(), 
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
} 