import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

// Match model for last matches
class Match {
  String homeTeam;
  String awayTeam;
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
    // A következő forduló mérkőzéseinél a score null lehet
    final score = json['score'];
    final fullTime = score != null ? score['fullTime'] : null;
    
    // Csapatnevek javítása, ha szükséges
    String homeTeamName = json['homeTeam']['name'] ?? 'Unknown';
    String awayTeamName = json['awayTeam']['name'] ?? 'Unknown';
    
    // Szélesebb körű javítás
    if (homeTeamName.toLowerCase().contains("primera") || homeTeamName.toLowerCase().contains("division")) {
      homeTeamName = "LaLiga";
    }
    if (awayTeamName.toLowerCase().contains("primera") || awayTeamName.toLowerCase().contains("division")) {
      awayTeamName = "LaLiga";
    }
    
    return Match(
      homeTeam: homeTeamName,
      awayTeam: awayTeamName,
      homeTeamLogo: json['homeTeam']['crest'],
      awayTeamLogo: json['awayTeam']['crest'],
      homeScore: fullTime != null ? (fullTime['home'] ?? 0) : 0,
      awayScore: fullTime != null ? (fullTime['away'] ?? 0) : 0,
      date: DateTime.parse(json['utcDate']),
    );
  }
}

// Csapat modell a tabellához
class TeamStanding {
  String teamName;
  final int position;
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
    String teamName = json['team']['name'] ?? 'Ismeretlen csapat';
    
    // Szélesebb körű javítás
    if (teamName.toLowerCase().contains("primera") || teamName.toLowerCase().contains("division")) {
      teamName = "LaLiga";
    }
    
    return TeamStanding(
      position: json['position'] ?? 0,
      teamName: teamName,
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
  late Future<List<Match>> futureNextMatches;
  bool isWideScreen = false;
  late String displayLeagueName;

  @override
  void initState() {
    super.initState();
    // Azonnali név javítás
    displayLeagueName = widget.leagueId == 2014 ? "LaLiga" : widget.leagueName;
        
    if (widget.leagueId == 2014) {
      print("DEBUG: Spanyol liga betöltése. Eredeti név: ${widget.leagueName}, javított név: $displayLeagueName");
    }
        
    futureStandings = fetchStandings(widget.leagueId);
    futureLastMatches = fetchLastRoundMatches(widget.leagueId);
    futureNextMatches = fetchNextRoundMatches(widget.leagueId);
  }

  Future<List<Match>> fetchLastRoundMatches(int leagueId) async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-footify-13da4.cloudfunctions.net/fetchLastRoundMatches?id=$leagueId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Rekurzívan javítjuk minden előfordulását a "Primera Division" szövegnek
        if (leagueId == 2014) {
          print("DEBUG: Utolsó forduló betöltése, rekurzív javítás indítása");
          fixPrimeraDivisionName(data);
          
          // Direct patch for competition name
          if (data.containsKey('competition') && data['competition'].containsKey('name')) {
            data['competition']['name'] = 'LaLiga';
            print("DEBUG: Verseny nevét közvetlenül javítottam LaLiga-ra");
          }
        }
        
        List<dynamic> matches = data['matches'];
        var result = matches.map((match) => Match.fromJson(match)).toList();
        
        // Még egyszer ellenőrizzük az eredményeket
        if (leagueId == 2014) {
          for (var match in result) {
            if (match.homeTeam.toLowerCase().contains("primera") || 
                match.homeTeam.toLowerCase().contains("division")) {
              print("DEBUG: Javítottam a homeTeam nevét: ${match.homeTeam} -> LaLiga");
              match.homeTeam = "LaLiga";
            }
            if (match.awayTeam.toLowerCase().contains("primera") || 
                match.awayTeam.toLowerCase().contains("division")) {
              print("DEBUG: Javítottam a awayTeam nevét: ${match.awayTeam} -> LaLiga");
              match.awayTeam = "LaLiga";
            }
          }
        }
        
        return result;
      } else {
        throw Exception('Failed to load last matches');
      }
    } catch (e) {
      print('Error fetching last matches: $e');
      return [];
    }
  }

  Future<List<Match>> fetchNextRoundMatches(int leagueId) async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-footify-13da4.cloudfunctions.net/fetchNextRoundMatches?id=$leagueId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Rekurzívan javítjuk minden előfordulását a "Primera Division" szövegnek
        if (leagueId == 2014) {
          print("DEBUG: Következő forduló betöltése, rekurzív javítás indítása");
          fixPrimeraDivisionName(data);
          
          // Direct patch for competition name
          if (data.containsKey('competition') && data['competition'].containsKey('name')) {
            data['competition']['name'] = 'LaLiga';
            print("DEBUG: Verseny nevét közvetlenül javítottam LaLiga-ra");
          }
        }
        
        List<dynamic> matches = data['matches'];
        var result = matches.map((match) => Match.fromJson(match)).toList();
        
        // Még egyszer ellenőrizzük az eredményeket
        if (leagueId == 2014) {
          for (var match in result) {
            if (match.homeTeam.toLowerCase().contains("primera") || 
                match.homeTeam.toLowerCase().contains("division")) {
              print("DEBUG: Javítottam a homeTeam nevét: ${match.homeTeam} -> LaLiga");
              match.homeTeam = "LaLiga";
            }
            if (match.awayTeam.toLowerCase().contains("primera") || 
                match.awayTeam.toLowerCase().contains("division")) {
              print("DEBUG: Javítottam a awayTeam nevét: ${match.awayTeam} -> LaLiga");
              match.awayTeam = "LaLiga";
            }
          }
        }
        
        return result;
      } else {
        throw Exception('Failed to load next matches');
      }
    } catch (e) {
      print('Error fetching next matches: $e');
      return [];
    }
  }

  Future<List<TeamStanding>> fetchStandings(int leagueId) async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-footify-13da4.cloudfunctions.net/fetchLeagueStandings?id=$leagueId'),
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        
        // Rekurzívan javítjuk minden előfordulását a "Primera Division" szövegnek
        if (leagueId == 2014) {
          print("DEBUG: Tabella betöltése, rekurzív javítás indítása");
          fixPrimeraDivisionName(responseData);
          
          // Direct patch for table title
          if (responseData.containsKey('competition') && responseData['competition'].containsKey('name')) {
            responseData['competition']['name'] = 'LaLiga';
            print("DEBUG: Tabella címét közvetlenül javítottam LaLiga-ra");
          }
        }
        
        List<dynamic> standings = responseData['standings'][0]['table'];
        var result = standings.map((team) => TeamStanding.fromJson(team)).toList();
        
        // Még egyszer ellenőrizzük az eredményeket
        if (leagueId == 2014) {
          for (var team in result) {
            team.teamName = fixPrimeraToLaLiga(team.teamName);
          }
        }
        
        return result;
      } else {
        throw Exception('Nem sikerült betölteni a tabellát');
      }
    } catch (e) {
      print('Error fetching standings: $e');
      throw Exception('Nem sikerült betölteni a tabellát');
    }
  }

  // Rekurzívan megkeresi és javítja a "Primera Division" előfordulásait a JSON-ban
  void fixPrimeraDivisionName(dynamic json) {
    if (json is Map) {
      // Map típusok átvizsgálása
      json.forEach((key, value) {
        if (value is String) {
          if (widget.leagueId == 2014 && (value.toLowerCase().contains("primera") || value.toLowerCase().contains("primiera"))) {
            print("DEBUG: Találtam 'Primera Division'-t az API válaszban: $key = $value");
            json[key] = "LaLiga";
          }
        } else if (value is Map || value is List) {
          fixPrimeraDivisionName(value);
        }
      });
    } else if (json is List) {
      // List típusok átvizsgálása
      for (var item in json) {
        if (item is Map || item is List) {
          fixPrimeraDivisionName(item);
        }
      }
    }
  }

  Color getPositionColor(int position, int leagueId) {
    // Premier League
    if (leagueId == 2021) {
      if (position <= 4) return Colors.blue; // Champions League
      if (position <= 6) return Colors.orange; // Europa League
      if (position >= 18) return Colors.red; // Relegation
    }
    // LaLiga
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
      case 2014: // LaLiga
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
      case 2014: // LaLiga
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
      // Direkt módon próbáljuk betölteni a képet webes verzióban (CORS-t figyelmen kívül hagyva)
      // A közvetlen betöltés gyakran jobb minőséget eredményez
      // Ha CORS hiba lenne, visszatérünk a proxy-hoz
      return originalUrl;
    }
    // Közvetlen URL használata mobil verzióban
    return originalUrl;
  }

  // Fallback proxy URL létrehozása CORS problémák esetén
  String getFallbackProxyUrl(String originalUrl) {
    return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    isWideScreen = screenWidth > 900;

    // Mindig ellenőrizzük és javítjuk a címet, ha spanyol ligáról van szó
    final String titleText = widget.leagueId == 2014 ? "LaLiga" : displayLeagueName;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
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
          child: _buildNextMatches(isDarkMode),
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
        const SizedBox(height: 16),
        _buildNextMatches(isDarkMode),
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
                'Legutóbbi forduló',
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
                    correctLeagueName(match.homeTeam),
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
                    correctLeagueName(match.awayTeam),
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
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.white,
        shape: BoxShape.circle,
      ),
      child: logoUrl != null
          ? kIsWeb 
            ? Image.network(
                getProxiedImageUrl(logoUrl),
                fit: BoxFit.contain,
                width: 28,
                height: 28,
                headers: {'Origin': 'null'},
                cacheWidth: 64,
                cacheHeight: 64,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  // Ha közvetlenül nem sikerül betölteni, próbáljuk a proxy-n keresztül
                  return Image.network(
                    getFallbackProxyUrl(logoUrl),
                    fit: BoxFit.contain,
                    width: 28,
                    height: 28,
                    cacheWidth: 64,
                    cacheHeight: 64,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      print("Csapatlogó betöltési hiba: $error");
                      return const Icon(Icons.sports_soccer, size: 20);
                    },
                  );
                },
              )
            : Image.network(
                getProxiedImageUrl(logoUrl),
                fit: BoxFit.contain,
                cacheWidth: 64,
                cacheHeight: 64,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  print("Csapatlogó betöltési hiba: $error");
                  return const Icon(Icons.sports_soccer, size: 20);
                },
              )
          : const Icon(Icons.sports_soccer, size: 20),
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
                                  width: 40, // Megnövelt méret
                                  height: 40, // Megnövelt méret
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: kIsWeb 
                                    ? Image.network(
                                        getProxiedImageUrl(team.teamLogo),
                                        fit: BoxFit.contain,
                                        width: 36,
                                        height: 36,
                                        headers: {'Origin': 'null'},
                                        cacheWidth: 72, // Nagyobb felbontású kép cache-elése
                                        cacheHeight: 72, // Nagyobb felbontású kép cache-elése
                                        filterQuality: FilterQuality.high, // Jobb minőségű szűrés
                                        errorBuilder: (context, error, stackTrace) {
                                          // Ha közvetlenül nem sikerül betölteni, próbáljuk a proxy-n keresztül
                                          return Image.network(
                                            getFallbackProxyUrl(team.teamLogo!),
                                            fit: BoxFit.contain,
                                            width: 36, 
                                            height: 36,
                                            cacheWidth: 72,
                                            cacheHeight: 72, 
                                            filterQuality: FilterQuality.high,
                                            errorBuilder: (context, error, stackTrace) {
                                              print("Tabella csapatlogó betöltési hiba: $error");
                                              return const Icon(Icons.sports_soccer, size: 24);
                                            },
                                          );
                                        },
                                      )
                                    : Image.network(
                                        getProxiedImageUrl(team.teamLogo),
                                        fit: BoxFit.contain,
                                        cacheWidth: 72,
                                        cacheHeight: 72,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder: (context, error, stackTrace) {
                                          print("Tabella csapatlogó betöltési hiba: $error");
                                          return const Icon(Icons.sports_soccer, size: 24);
                                        },
                                      ),
                                )
                              : Container(
                                  width: 40, // Megnövelt méret
                                  height: 40, // Megnövelt méret
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.sports_soccer, size: 24),
                                ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                correctLeagueName(team.teamName),
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

  Widget _buildNextMatches(bool isDarkMode) {
    return FutureBuilder<List<Match>>(
      future: futureNextMatches,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Hiba: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nincs elérhető következő mérkőzés'));
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
                'Következő forduló',
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
                  return _buildNextMatchCard(match, isDarkMode);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNextMatchCard(Match match, bool isDarkMode) {
    // A következő mérkőzések még nem játszódtak le, ezért nincs eredmény
    String formattedDate = '';
    try {
      // Dátum formázása: "márc. 15. 15:30"
      final day = match.date.day;
      final month = _getHungarianMonth(match.date.month);
      final hour = match.date.hour.toString().padLeft(2, '0');
      final minute = match.date.minute.toString().padLeft(2, '0');
      formattedDate = '$month $day. $hour:$minute';
    } catch (e) {
      formattedDate = 'Időpont ismeretlen';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              formattedDate,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildTeamLogo(match.homeTeamLogo, isDarkMode),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        correctLeagueName(match.homeTeam),
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
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDarkMode ? Colors.amber[200] : Colors.amber[800],
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        correctLeagueName(match.awayTeam),
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
        ],
      ),
    );
  }

  String _getHungarianMonth(int month) {
    const months = [
      'jan.', 'febr.', 'márc.', 'ápr.', 'máj.', 'jún.',
      'júl.', 'aug.', 'szept.', 'okt.', 'nov.', 'dec.'
    ];
    return months[month - 1];
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

  // Globális segédfüggvény a bajnokságnevek javítására a teljes alkalmazásban
  String correctLeagueName(String originalName) {
    // Speciális rövidítés a spanyol liga számára
    if (widget.leagueId == 2014) {
      if (originalName.toLowerCase().contains("primera") || 
          originalName.toLowerCase().contains("primiera") ||
          originalName.toLowerCase().contains("primavera") || 
          originalName.toLowerCase().contains("division")) {
        return "LaLiga";
      }
    }
    
    // Általános javítás minden esetben
    if (originalName.toLowerCase().contains("primera division") || 
        originalName.toLowerCase() == "primera" ||
        originalName.toLowerCase() == "primera división") {
      return "LaLiga";
    }
    
    return originalName;
  }
}

// Az osztályon kívül, globális függvény a név javítására
String fixPrimeraToLaLiga(String input) {
  if (input.toLowerCase().contains("primera") || input.toLowerCase().contains("primiera")) {
    return "LaLiga";
  }
  return input;
} 