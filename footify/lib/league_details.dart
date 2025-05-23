import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Match model for last matches
class Match {
  final String homeTeam;
  final String? homeTeamShortName;
  final String awayTeam;
  final String? awayTeamShortName;
  final String? homeTeamLogo;
  final String? awayTeamLogo;
  final int homeScore;
  final int awayScore;
  final DateTime date;

  Match({
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamShortName,
    this.awayTeamShortName,
    required this.homeTeamLogo,
    required this.awayTeamLogo,
    required this.homeScore,
    required this.awayScore,
    required this.date,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      homeTeam: json['homeTeam']?['name'] ?? 'Unknown',
      awayTeam: json['awayTeam']?['name'] ?? 'Unknown',
      homeTeamShortName: json['homeTeam']?['shortName'],
      awayTeamShortName: json['awayTeam']?['shortName'],
      homeTeamLogo: json['homeTeam']?['crest'],
      awayTeamLogo: json['awayTeam']?['crest'],
      homeScore: json['score']?['fullTime']?['home'] ?? 0,
      awayScore: json['score']?['fullTime']?['away'] ?? 0,
      date: DateTime.parse(json['utcDate'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// Góllövő modell
class Scorer {
  final String playerName;
  final String teamName;
  final String? teamShortName;
  final String? teamLogo;
  final int goals;

  Scorer({
    required this.playerName,
    required this.teamName,
    this.teamShortName,
    required this.teamLogo,
    required this.goals,
  });

  factory Scorer.fromJson(Map<String, dynamic> json) {
    return Scorer(
      playerName: json['player']?['name'] ?? 'Unknown Player',
      teamName: json['team']?['name'] ?? 'Unknown Team',
      teamShortName: json['team']?['shortName'],
      teamLogo: json['team']?['crest'],
      goals: json['goals'] ?? 0,
    );
  }
}

// Csapat modell a tabellához
class TeamStanding {
  final int position;
  final String teamName;
  final String? teamShortName;
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
    this.teamShortName,
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
      teamName: json['team']?['name'] ?? 'Unknown Team',
      teamShortName: json['team']?['shortName'],
      teamLogo: json['team']?['crest'],
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
  final String? leagueLogo;

  const LeagueDetailsPage({super.key, required this.leagueId, required this.leagueName, this.leagueLogo});

  @override
  State<LeagueDetailsPage> createState() => _LeagueDetailsPageState();
}

class _LeagueDetailsPageState extends State<LeagueDetailsPage> with SingleTickerProviderStateMixin {
  late Future<List<TeamStanding>> futureStandings;
  late Future<List<Match>> futureLastMatches;
  late Future<List<Scorer>> futureScorers;
  late TabController _tabController;
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
    _tabController = TabController(length: 3, vsync: this);
    futureStandings = fetchStandings(widget.leagueId);
    futureLastMatches = fetchLastRoundMatches(widget.leagueId);
    futureScorers = Future.value([]); // Alapértelmezett üres lista
    _loadScorers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        throw Exception('Failed to load standings');
      }
    } catch (e) {
      print('Error fetching standings: $e');
      throw Exception('Failed to load standings');
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
    // Premier League, La Liga, Serie A (UCL, UEL, Relegation)
    if (leagueId == 2021 || leagueId == 2014 || leagueId == 2019) {
      if (position <= 4) return Colors.blue; // UCL
      if (position <= 6) return Colors.orange; // UEL
      if (position >= 18) return Colors.red; // Relegation
    }
    // Bundesliga (UCL, UEL, Relegation)
    else if (leagueId == 2002) {
      if (position <= 4) return Colors.blue; // UCL
      if (position <= 6) return Colors.orange; // UEL
      if (position >= 16) return Colors.red; // Relegation
    }
    // Ligue 1 (UCL, UEL, Relegation)
    else if (leagueId == 2015) {
      if (position <= 2) return Colors.blue; // UCL
      if (position <= 4) return Colors.orange; // UEL
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

  String getQualificationTextForLeague(BuildContext context, int leagueId) {
    switch (leagueId) {
      case 2021: // Premier League
        return AppLocalizations.of(context)!.premierLeagueQualification;
      case 2014: // La Liga
        return AppLocalizations.of(context)!.laLigaQualification;
      case 2019: // Serie A
        return AppLocalizations.of(context)!.serieAQualification;
      case 2002: // Bundesliga
        return AppLocalizations.of(context)!.bundesligaQualification;
      case 2015: // Ligue 1
        return AppLocalizations.of(context)!.ligue1Qualification;
      case 2016: // Championship
        return AppLocalizations.of(context)!.championshipQualification;
      case 2017: // League One
        return AppLocalizations.of(context)!.leagueOneQualification;
      default:
        return '';
    }
  }

  List<Map<String, dynamic>> getRelevantColors(int leagueId) {
    final localizations = AppLocalizations.of(context)!;
    switch (leagueId) {
      case 2021: // Premier League
      case 2014: // La Liga
      case 2019: // Serie A
      case 2002: // Bundesliga
        return [
          {'color': Colors.blue, 'name': localizations.championsLeague},
          {'color': Colors.orange, 'name': localizations.europaLeague},
          {'color': Colors.red, 'name': localizations.relegation},
        ];
      case 2015: // Ligue 1
        return [
          {'color': Colors.blue, 'name': localizations.championsLeague},
          {'color': Colors.orange, 'name': localizations.europaLeague},
          {'color': Colors.red, 'name': localizations.relegation},
        ];
      case 2016: // Championship
      case 2017: // League One
        return [
          {'color': Colors.green, 'name': localizations.automaticPromotion},
          {'color': Colors.orange, 'name': localizations.playoffPromotion},
          {'color': Colors.red, 'name': localizations.relegation},
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

  // Frissített segédfüggvény az online logók megjelenítéséhez
  Widget _buildLogoImage(int leagueId, String? logoUrl, bool isDarkMode, bool isWeb) {
    // Jobb minőségű helyettesítő logók a bajnokságokhoz
    Map<int, String> replacementLogos = {
      2013: 'https://upload.wikimedia.org/wikipedia/en/0/04/Campeonato_Brasileiro_S%C3%A9rie_A.png', // Brasileiro Série A
      2018: 'https://static.wikia.nocookie.net/future/images/8/84/Euro_2028_Logo_Concept_v2.png/revision/latest?cb=20231020120018', // European Championship
      2003: 'https://upload.wikimedia.org/wikipedia/commons/4/46/Eredivisie_nuovo_logo.png', // Eredivisie
      2000: 'https://upload.wikimedia.org/wikipedia/en/thumb/1/17/2026_FIFA_World_Cup_emblem.svg/1200px-2026_FIFA_World_Cup_emblem.svg.png', // FIFA World Cup
      2015: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Ligue1_Uber_Eats_logo.png/1200px-Ligue1_Uber_Eats_logo.png', // Ligue 1 (nagyobb felbontás)
      2019: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/Serie_A_logo_2022.svg/1200px-Serie_A_logo_2022.svg.png', // Serie A
      2014: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/LaLiga_logo_2023.svg/2560px-LaLiga_logo_2023.svg.png', // LaLiga
      2021: 'https://www.sportmonks.com/wp-content/uploads/2024/08/Premier_League_Logo-1.png', // Premier League 
      2152: 'https://upload.wikimedia.org/wikipedia/en/thumb/a/a1/Copa_Libertadores_logo.svg/1200px-Copa_Libertadores_logo.svg.png', // Copa Libertadores
      2001: 'https://assets-us-01.kc-usercontent.com/31dbcbc6-da4c-0033-328a-d7621d0fa726/8e5c2681-8c90-4c64-a79d-2a4fa17834c7/UEFA_Champions_League_Logo.png', // Champions League
      2002: 'https://upload.wikimedia.org/wikipedia/en/thumb/d/df/Bundesliga_logo_%282017%29.svg/1200px-Bundesliga_logo_%282017%29.svg.png', // Bundesliga
      2017: 'https://news.22bet.com/wp-content/uploads/2023/11/liga-portugal-logo-white.png', // Primeira Liga
    };
    
    // Sötét témájú verziók a világos módban nem jól látható logókhoz
    Map<int, String> darkVersionLogos = {
      2021: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Premier_League_Logo.svg/1200px-Premier_League_Logo.svg.png', // Premier League (sötét verzió)
      2001: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f5/UEFA_Champions_League.svg/1200px-UEFA_Champions_League.svg.png', // Champions League (sötét verzió)
      2017: 'https://cdn.freelogovectors.net/wp-content/uploads/2021/08/primeira-logo-liga-portugal-freelogovectors.net_.png', // Primeira Liga (sötét verzió)
    };
    
    // Világos témájú verziók a sötét módhoz
    Map<int, String> lightVersionLogos = {
      2021: 'https://www.sportmonks.com/wp-content/uploads/2024/08/Premier_League_Logo-1.png', // Premier League (fehér verzió)
      2017: 'https://news.22bet.com/wp-content/uploads/2023/11/liga-portugal-logo-white.png', // Primeira Liga (fehér verzió)
    };
    
    // Proxy használata a webes verzióban, minőségi paraméterrel
    String getProxiedUrl(String url) {
      if (kIsWeb) {
        // Ha SVG formátumú a kép, közvetlenül használjuk
        if (url.toLowerCase().endsWith('.svg') || url.toLowerCase().contains('.svg')) {
          return url;
        }
        return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(url)}';
      }
      return url;
    }

    // A problémás ligák világos módban sötét verziójú képet használnak
    if (!isDarkMode && darkVersionLogos.containsKey(leagueId)) {
      return Image.network(
        getProxiedUrl(darkVersionLogos[leagueId]!),
        fit: BoxFit.contain,
        // Webes felületen kisebb képek
        width: isWeb ? 50 : 70,
        height: isWeb ? 50 : 70,
        headers: kIsWeb ? {'Origin': 'null'} : null,
        errorBuilder: (context, error, stackTrace) {
          print("Sötét verzió betöltési hiba (ID: $leagueId): $error");
          return Icon(
            Icons.sports_soccer, 
            size: isWeb ? 30 : 40,
            color: Colors.black54,
          );
        },
      );
    }
    
    // A problémás ligák sötét módban világos/fehér verziójú képet használnak
    if (isDarkMode && lightVersionLogos.containsKey(leagueId)) {
      return Image.network(
        getProxiedUrl(lightVersionLogos[leagueId]!),
        fit: BoxFit.contain,
        // Webes felületen kisebb képek
        width: isWeb ? 50 : 70,
        height: isWeb ? 50 : 70,
        headers: kIsWeb ? {'Origin': 'null'} : null,
        errorBuilder: (context, error, stackTrace) {
          print("Világos verzió betöltési hiba (ID: $leagueId): $error");
          return Icon(
            Icons.sports_soccer, 
            size: isWeb ? 30 : 40,
            color: Colors.white70,
          );
        },
      );
    }
    
    // Eredivisie esetén fehérre színezzük sötét módban
    if (leagueId == 2003 && isDarkMode && replacementLogos.containsKey(leagueId)) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
        child: Image.network(
          getProxiedUrl(replacementLogos[leagueId]!),
          fit: BoxFit.contain,
          // Webes felületen kisebb képek
          width: isWeb ? 50 : 70,
          height: isWeb ? 50 : 70,
          headers: kIsWeb ? {'Origin': 'null'} : null,
          errorBuilder: (context, error, stackTrace) {
            print("Helyettesítő kép betöltési hiba (ID: $leagueId): $error");
            return Icon(
              Icons.sports_soccer, 
              size: isWeb ? 30 : 40,
              color: Colors.white70,
            );
          },
        ),
      );
    }
    
    // Premier League és Bajnokok Ligája esetén fehér szín sötét módban - csak a Champions League esetén használjuk
    if (leagueId == 2001 && isDarkMode) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
        child: Image.network(
          getProxiedUrl(logoUrl ?? replacementLogos[leagueId]!),
          fit: BoxFit.contain,
          // Webes felületen kisebb képek
          width: isWeb ? 50 : 70,
          height: isWeb ? 50 : 70,
          headers: kIsWeb ? {'Origin': 'null'} : null,
          errorBuilder: (context, error, stackTrace) {
            print("Fehérre színezett logó betöltési hiba (ID: $leagueId): $error");
            return Icon(
              Icons.sports_soccer, 
              size: isWeb ? 30 : 40,
              color: Colors.white70,
            );
          },
        ),
      );
    }
    
    // Ellenőrizzük, hogy van-e helyettesítő online kép
    if (replacementLogos.containsKey(leagueId)) {
      return Image.network(
        getProxiedUrl(replacementLogos[leagueId]!),
        fit: BoxFit.contain,
        // Webes felületen kisebb képek
        width: isWeb ? 50 : 70,
        height: isWeb ? 50 : 70,
        headers: kIsWeb ? {'Origin': 'null'} : null,
        errorBuilder: (context, error, stackTrace) {
          print("Helyettesítő kép betöltési hiba (ID: $leagueId): $error");
          return Icon(
            Icons.sports_soccer, 
            size: isWeb ? 30 : 40,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          );
        },
      );
    }
    
    // Minden más esetben az eredeti logót használjuk
    return _getNetworkImage(logoUrl, isDarkMode, isWeb);
  }
  
  // Segédfüggvény a hálózati kép megjelenítéséhez
  Widget _getNetworkImage(String? logoUrl, bool isDarkMode, bool isWeb) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Icon(
        Icons.sports_soccer, 
        size: isWeb ? 30 : 40,
        color: isDarkMode ? Colors.white70 : Colors.black54,
      );
    }
    
    // Proxy használata a webes verzióban
    String proxyUrl = logoUrl;
    if (kIsWeb) {
      // Ha SVG formátumú a kép, közvetlenül használjuk
      if (logoUrl.toLowerCase().endsWith('.svg') || logoUrl.toLowerCase().contains('.svg')) {
        proxyUrl = logoUrl;
      } else {
        proxyUrl = 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(logoUrl)}';
      }
    }
    
    return Image.network(
      proxyUrl,
      fit: BoxFit.contain,
      // Webes felületen kisebb képek
      width: isWeb ? 50 : 70,
      height: isWeb ? 50 : 70,
      headers: kIsWeb ? {'Origin': 'null'} : null,
      errorBuilder: (context, error, stackTrace) {
        print("Eredeti logó betöltési hiba: $error");
        return Icon(
          Icons.sports_soccer, 
          size: isWeb ? 30 : 40,
          color: isDarkMode ? Colors.white70 : Colors.black54,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    isWideScreen = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.leagueLogo != null)
              SizedBox(
                width: 30,
                height: 30,
                child: _buildLogoImage(widget.leagueId, widget.leagueLogo, isDarkMode, kIsWeb),
              ),
            if (widget.leagueLogo != null)
              const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.leagueName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        bottom: !isWideScreen ? TabBar(
          controller: _tabController,
          labelColor: isDarkMode ? Colors.white : Colors.black,
          unselectedLabelColor: isDarkMode ? Colors.grey : Colors.grey[600],
          indicatorColor: const Color(0xFFFFE6AC),
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 15),
          indicatorWeight: 3,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 16),
          tabs: [
            Tab(
              child: Text(
                AppLocalizations.of(context)!.standings,
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
            Tab(
              child: Text(
                AppLocalizations.of(context)!.lastRound,
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
            Tab(
              child: Text(
                AppLocalizations.of(context)!.statistics,
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ) : null,
      ),
      body: SafeArea(
        child: isWideScreen
            ? SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildLastMatches(isDarkMode),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: FutureBuilder<List<TeamStanding>>(
                          future: futureStandings,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return Center(child: Text('Hiba: ${snapshot.error}'));
                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(child: Text(AppLocalizations.of(context)!.noMatchesAvailable));
                            }
                            return Column(
                              children: [
                                _buildStandingsTable(snapshot.data!, isDarkMode),
                                _buildLegend(isDarkMode),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildScorers(isDarkMode),
                      ),
                    ],
                  ),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  // Tabella tab
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          FutureBuilder<List<TeamStanding>>(
                            future: futureStandings,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(child: Text('Hiba: ${snapshot.error}'));
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return Center(child: Text(AppLocalizations.of(context)!.noMatchesAvailable));
                              }
                              return Column(
                                children: [
                                  _buildStandingsTable(snapshot.data!, isDarkMode),
                                  _buildLegend(isDarkMode),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Előző forduló tab
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildLastMatches(isDarkMode),
                    ),
                  ),
                  // Statisztikák tab
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildScorers(isDarkMode),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
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
                      AppLocalizations.of(context)!.positionColumnHeader,
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
                      AppLocalizations.of(context)!.teamColumnHeader,
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
                      AppLocalizations.of(context)!.matchesColumnHeader,
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
                        AppLocalizations.of(context)!.goalsForColumnHeader,
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
                        AppLocalizations.of(context)!.goalsAgainstColumnHeader,
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
                      AppLocalizations.of(context)!.goalDifferenceColumnHeader,
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
                      AppLocalizations.of(context)!.pointsColumnHeader,
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
                    // Color Indicator
                    Container(
                      width: 4, // Width of the vertical line
                      height: 56, // Match the approximate row height
                      color: positionColor,
                    ),
                    // Existing Row Content (wrapped in Expanded)
                    Expanded(
                      child: Row(
                        children: [
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
                                    ? SizedBox(
                                        width: 32, // Increased from 28
                                        height: 32, // Increased from 28
                                        child: Image.network(
                                          getProxiedImageUrl(team.teamLogo),
                                          fit: BoxFit.contain,
                                          width: 32,
                                          height: 32,
                                          headers: kIsWeb ? {'Origin': 'null'} : null,
                                          errorBuilder: (context, error, stackTrace) {
                                            print("Tabella csapatlogó betöltési hiba: $error");
                                            return const Icon(Icons.sports_soccer, size: 22);
                                          },
                                        ),
                                      )
                                    : SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: const Icon(Icons.sports_soccer, size: 22),
                                      ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      team.teamShortName?.isNotEmpty == true 
                                        ? team.teamShortName! 
                                        : team.teamName,
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
                    ),
                  ],
                ),
              );
            },
          ),
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
                AppLocalizations.of(context)!.previousRound,
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
        color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
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
                    match.homeTeamShortName?.isNotEmpty == true 
                      ? match.homeTeamShortName! 
                      : match.homeTeam,
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
                    match.awayTeamShortName?.isNotEmpty == true 
                      ? match.awayTeamShortName! 
                      : match.awayTeam,
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
    
    return SizedBox(
      width: 34, // Slightly increased from 30
      height: 34, // Slightly increased from 30
      child: logoUrl != null
          ? Image.network(
              getProxiedImageUrl(logoUrl),
              fit: BoxFit.contain,
              headers: kIsWeb ? {'Origin': 'null'} : null,
              errorBuilder: (context, error, stackTrace) {
                print("Csapatlogó betöltési hiba: $error");
                return const Icon(Icons.sports_soccer, size: 18);
              },
            )
          : const Icon(Icons.sports_soccer, size: 18),
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
            child: Center(child: Text(AppLocalizations.of(context)!.noScorersAvailable)),
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
                AppLocalizations.of(context)!.topScorers,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ...snapshot.data!.map((scorer) => _buildScorerCard(scorer, snapshot.data!.indexOf(scorer) + 1, isDarkMode)),
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
        color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Helyezés
          SizedBox(
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
                  scorer.teamShortName?.isNotEmpty == true 
                    ? scorer.teamShortName! 
                    : scorer.teamName,
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
              '${scorer.goals} ${AppLocalizations.of(context)!.goals}',
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...relevantColors.map((colorInfo) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
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
              ),
            );
          }),
        ],
      ),
    );
  }
} 