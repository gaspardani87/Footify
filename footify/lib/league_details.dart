import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

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

// Góllövő modell
class Scorer {
  final String playerName;
  final String teamName;
  final String? teamLogo;
  final int goals;

  Scorer({
    required this.playerName,
    required this.teamName,
    required this.teamLogo,
    required this.goals,
  });

  factory Scorer.fromJson(Map<String, dynamic> json) {
    return Scorer(
      playerName: json['player']['name'] ?? 'Ismeretlen játékos',
      teamName: json['team']['name'] ?? 'Ismeretlen csapat',
      teamLogo: json['team']['crest'],
      goals: json['goals'] ?? 0,
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
  late Future<List<Scorer>> futureScorers;
  bool isWideScreen = false;

  // Liga ID-k megfeleltetése az API kódokkal
  String getLeagueCode(int leagueId) {
    switch (leagueId) {
      case 2021:
        return 'PL'; // Premier League
      case 2014:
        return 'PD'; // La Liga
      case 2019:
        return 'SA'; // Serie A
      case 2002:
        return 'BL1'; // Bundesliga
      case 2015:
        return 'FL1'; // Ligue 1
      case 2016:
        return 'ELC'; // Championship
      case 2017:
        return 'EL1'; // League One
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    futureStandings = fetchStandings(widget.leagueId);
    futureLastMatches = fetchLastRoundMatches(widget.leagueId);
    futureScorers = Future.value([]); // Alapértelmezett üres lista
    _loadScorers();
  }

  Future<void> _loadScorers() async {
    try {
      final leagueCode = getLeagueCode(widget.leagueId);
      if (leagueCode.isEmpty) {
        setState(() {
          futureScorers = Future.value([]);
        });
        return;
      }

      setState(() {
        futureScorers = fetchScorers(widget.leagueId);
      });
    } catch (e) {
      print('Hiba a góllövőlista betöltésekor: $e');
      setState(() {
        futureScorers = Future.value([]);
      });
    }
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

  Future<List<Scorer>> fetchScorers(int leagueId) async {
    try {
      final leagueCode = getLeagueCode(leagueId);
      if (leagueCode.isEmpty) return [];

      final response = await http.get(
        Uri.parse('https://us-central1-footify-13da4.cloudfunctions.net/fetchTopScorers?leagueCode=$leagueCode'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['scorers'] != null) {
          List<dynamic> scorers = data['scorers'];
          return scorers.map((scorer) => Scorer.fromJson(scorer)).toList();
        }
      }
      print('Nem sikerült betölteni a góllövőlistát: ${response.statusCode}');
      print('Válasz: ${response.body}');
      return [];
    } catch (e) {
      print('Hiba a góllövőlista betöltésekor: $e');
      return [];
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

  // Proxy képek URL-jét a webes verzióban
  String getProxiedImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return '';
    if (kIsWeb) {
      // Ha SVG formátumú a kép, közvetlenül használjuk
      if (originalUrl.toLowerCase().endsWith('.svg') || originalUrl.toLowerCase().contains('.svg')) {
        return originalUrl;
      }
      // Proxy a Firebase funkción keresztül webes verzió esetén
      return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
    }
    // Közvetlen URL használata mobil verzióban
    return originalUrl;
  }

  // Minőségi csapatlogók alternatív URL-jei
  String getHighQualityTeamLogo(String? logoUrl, String teamName) {
    if (logoUrl == null || logoUrl.isEmpty) return '';
    
    // Ismert csapatok jobb minőségű logói
    final Map<String, String> teamLogos = {
      'Arsenal FC': 'https://upload.wikimedia.org/wikipedia/en/5/53/Arsenal_FC.svg',
      'Manchester United FC': 'https://upload.wikimedia.org/wikipedia/en/7/7a/Manchester_United_FC_crest.svg',
      'Liverpool FC': 'https://upload.wikimedia.org/wikipedia/en/0/0c/Liverpool_FC.svg',
      'Chelsea FC': 'https://upload.wikimedia.org/wikipedia/en/c/cc/Chelsea_FC.svg',
      'Manchester City FC': 'https://upload.wikimedia.org/wikipedia/en/e/eb/Manchester_City_FC_badge.svg',
      'Tottenham Hotspur FC': 'https://upload.wikimedia.org/wikipedia/en/b/b4/Tottenham_Hotspur.svg',
      'FC Barcelona': 'https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg',
      'Real Madrid CF': 'https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg',
      'FC Bayern München': 'https://upload.wikimedia.org/wikipedia/commons/1/1b/FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg',
      'Paris Saint-Germain FC': 'https://upload.wikimedia.org/wikipedia/en/a/a7/Paris_Saint-Germain_F.C..svg',
      'Juventus FC': 'https://upload.wikimedia.org/wikipedia/commons/b/bc/Juventus_FC_2017_icon.svg',
      'Borussia Dortmund': 'https://upload.wikimedia.org/wikipedia/commons/6/67/Borussia_Dortmund_logo.svg',
      'AC Milan': 'https://upload.wikimedia.org/wikipedia/commons/d/d0/AC_Milan_logo.svg',
      'Inter Milan': 'https://upload.wikimedia.org/wikipedia/commons/0/05/FC_Internazionale_Milano_2021.svg',
      'Atlético Madrid': 'https://upload.wikimedia.org/wikipedia/en/f/f4/Atletico_Madrid_2017_logo.svg',
    };
    
    // Ha találunk jobb minőségű logót a csapathoz
    if (teamLogos.containsKey(teamName)) {
      return teamLogos[teamName]!;
    }
    
    return logoUrl;
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
          child: _buildScorers(isDarkMode),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(List<TeamStanding> standings, bool isDarkMode) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildStandingsTable(standings, isDarkMode),
          const SizedBox(height: 16),
          _buildLastMatches(isDarkMode),
          const SizedBox(height: 16),
          _buildScorers(isDarkMode),
          const SizedBox(height: 16), // Extra padding az alján
        ],
      ),
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
    // Egyedi azonosítót készítünk a logóból
    String? logoId = logoUrl?.split('/').last.split('.').first;
    
    return Container(
      width: 30, // Kicsit nagyobb méret
      height: 30, // Kicsit nagyobb méret
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: logoUrl != null
          ? Image.network(
              getProxiedImageUrl(logoUrl),
              fit: BoxFit.contain,
              headers: kIsWeb ? {'Origin': 'null'} : null,
              errorBuilder: (context, error, stackTrace) {
                print("Csapatlogó betöltési hiba: $error");
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Fejléc
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Színjelölő
                const SizedBox(width: 2),
                
                // Helyezés (#)
                SizedBox(
                  width: 32,
                  height: 48,
                  child: Center(
                    child: Text(
                      '#',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                
                // Csapat
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Csapat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                
                // Lejátszott meccsek (M)
                SizedBox(
                  width: 36,
                  height: 48,
                  child: Center(
                    child: Text(
                      'M',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 4), // Térköz az oszlopok között
                
                // További oszlopok csak széles képernyőn
                if (isWideScreen) ...[
                  SizedBox(
                    width: 36,
                    height: 48,
                    child: Center(
                      child: Text(
                        'G+',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4), // Térköz az oszlopok között
                  SizedBox(
                    width: 36,
                    height: 48,
                    child: Center(
                      child: Text(
                        'G-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4), // Térköz az oszlopok között
                ],
                
                // Gólkülönbség (GK)
                SizedBox(
                  width: 36,
                  height: 48,
                  child: Center(
                    child: Text(
                      'GK',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 4), // Térköz az oszlopok között
                
                // Pontszám (P)
                SizedBox(
                  width: 36,
                  height: 48,
                  child: Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16), // Jobb margó
              ],
            ),
          ),
          
          // Sorok
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            shrinkWrap: true, // Ez biztosítja, hogy a ListView az összes tartalmát megjelenítse
            itemCount: standings.length,
            itemBuilder: (context, index) {
              final team = standings[index];
              final positionColor = getPositionColor(team.position, widget.leagueId);
              
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Színjelölő
                    Container(
                      width: 2,
                      height: 56,
                      color: positionColor,
                    ),
                    
                    // Helyezés (#)
                    SizedBox(
                      width: 32,
                      height: 56,
                      child: Center(
                        child: Text(
                          team.position.toString(),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    
                    // Csapat név és logó
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            team.teamLogo != null
                              ? Container(
                                  width: 28, // Nagyobb méret a jobb minőséghez
                                  height: 28, // Nagyobb méret a jobb minőséghez
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Image.network(
                                    getProxiedImageUrl(team.teamLogo),
                                    fit: BoxFit.contain,
                                    width: 28, // Nagyobb méret a jobb minőséghez
                                    height: 28, // Nagyobb méret a jobb minőséghez
                                    headers: kIsWeb ? {'Origin': 'null'} : null,
                                    errorBuilder: (context, error, stackTrace) {
                                      print("Tabella csapatlogó betöltési hiba: $error");
                                      return const Icon(Icons.sports_soccer, size: 20);
                                    },
                                  ),
                                )
                              : Container(
                                  width: 28, // Nagyobb méret a jobb minőséghez
                                  height: 28, // Nagyobb méret a jobb minőséghez
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.sports_soccer, size: 20),
                                ),
                            const SizedBox(width: 8),
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
                    
                    // Lejátszott meccsek (M)
                    SizedBox(
                      width: 36,
                      height: 56,
                      child: Center(
                        child: Text(
                          team.playedGames.toString(),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 4), // Térköz az oszlopok között
                    
                    // További adatok széles képernyőn
                    if (isWideScreen) ...[
                      SizedBox(
                        width: 36,
                        height: 56,
                        child: Center(
                          child: Text(
                            team.goalsFor.toString(),
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4), // Térköz az oszlopok között
                      SizedBox(
                        width: 36,
                        height: 56,
                        child: Center(
                          child: Text(
                            team.goalsAgainst.toString(),
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4), // Térköz az oszlopok között
                    ],
                    
                    // Gólkülönbség (GK)
                    SizedBox(
                      width: 36,
                      height: 56,
                      child: Center(
                        child: Text(
                          (team.goalsFor - team.goalsAgainst).toString(),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 4), // Térköz az oszlopok között
                    
                    // Pontszám (P)
                    SizedBox(
                      width: 36,
                      height: 56,
                      child: Center(
                        child: Text(
                          team.points.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16), // Jobb margó
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScorers(bool isDarkMode) {
    return FutureBuilder<List<Scorer>>(
      future: futureScorers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 100,
            child: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return SizedBox(
            height: 100,
            child: Center(child: Text('Hiba: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SizedBox(
            height: 100,
            child: const Center(child: Text('Nincs elérhető góllövő')),
          );
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Góllövőlista',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ...snapshot.data!.map((scorer) => _buildScorerCard(scorer, snapshot.data!.indexOf(scorer) + 1, isDarkMode)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScorerCard(Scorer scorer, int position, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Helyezés
          Container(
            width: 30,
            child: Row(
              children: [
                Text(
                  position.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  '.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Csapat logó
          _buildTeamLogo(scorer.teamLogo, isDarkMode),
          const SizedBox(width: 12),
          // Játékos neve és csapata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scorer.playerName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  scorer.teamName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Gólok száma
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6AC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${scorer.goals} gól',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
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