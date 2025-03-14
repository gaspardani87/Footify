import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'common_layout.dart';
import 'league_details.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Liga adatmodell
class League {
  final int id;
  final String name;
  final String? logo;

  League({required this.id, required this.name, required this.logo});

  factory League.fromJson(Map<String, dynamic> json) {
    // Ellenőrizzük a különböző lehetséges mezőneveket a logóhoz
    // Az API válasz struktúrája szerint navigálunk
    String? logoUrl;
    
    try {
      // Ellenőrzünk különböző mezőket, ahol a logó lehet
      if (json.containsKey('emblem')) {
        logoUrl = json['emblem'];
      } else if (json.containsKey('crest')) {
        logoUrl = json['crest'];
      } else if (json.containsKey('logo')) {
        logoUrl = json['logo'];
      } else if (json.containsKey('area') && json['area'] != null && json['area'].containsKey('flag')) {
        // Néhány API-ban az 'area' mezőben található a 'flag'
        logoUrl = json['area']['flag'];
      }
    } catch (e) {
      print("Hiba a logo keresése közben: $e");
    }

    // Bajnokság nevének javítása, ha szükséges
    String leagueName = json['name'] ?? 'Ismeretlen bajnokság';
    int leagueId = json['id'] ?? 0;
    
    // Ha ez a spanyol liga, vagy a neve tartalmazza a "Primera Division"-t, javítjuk
    if (leagueId == 2014 || leagueName.toLowerCase().contains("primera") || 
        leagueName.toLowerCase().contains("primiera") || 
        leagueName.toLowerCase().contains("division")) {
      leagueName = "LaLiga";
    }
    
    return League(
      id: json['id'],
      name: leagueName,
      logo: logoUrl,
    );
  }
}

class LeaguePage extends StatefulWidget {
  const LeaguePage({super.key});

  @override
  State<LeaguePage> createState() => _LeaguePageState();
}

class _LeaguePageState extends State<LeaguePage> {
  late Future<List<League>> futureLeagues;

  @override
  void initState() {
    super.initState();
    futureLeagues = fetchLeagues();
  }

  // Proxy képek URL-jét a webes verzióban
  String getProxiedImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return '';
    if (kIsWeb) {
      // Proxy a Firebase funkción keresztül webes verzió esetén
      return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
    }
    // Közvetlen URL használata mobil verzióban
    return originalUrl;
  }

  Future<List<League>> fetchLeagues() async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-footify-13da4.cloudfunctions.net/fetchLeagues'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => League.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load leagues');
      }
    } catch (e) {
      print('Error fetching leagues: $e');
      // Fallback to the original hardcoded list if the API call fails
      return [
        League(id: 2013, name: 'Brasileiro Série A', logo: 'https://crests.football-data.org/BSA.png'),
        League(id: 2016, name: 'EFL Championship', logo: 'https://crests.football-data.org/ELC.png'),
        League(id: 2021, name: 'Premier League', logo: 'https://crests.football-data.org/PL.png'),
        League(id: 2001, name: 'UEFA Champions League', logo: 'https://crests.football-data.org/CL.png'),
        League(id: 2018, name: 'European Championship', logo: 'https://crests.football-data.org/EUR.png'),
        League(id: 2015, name: 'Ligue 1', logo: 'https://crests.football-data.org/FL1.png'),
        League(id: 2002, name: 'Bundesliga', logo: 'https://crests.football-data.org/BL1.png'),
        League(id: 2019, name: 'Serie A', logo: 'https://crests.football-data.org/SA.png'),
        League(id: 2003, name: 'Eredivisie', logo: 'https://crests.football-data.org/DED.png'),
        League(id: 2017, name: 'Primeira Liga', logo: 'https://crests.football-data.org/PPL.png'),
        League(id: 2152, name: 'Copa Libertadores', logo: 'https://crests.football-data.org/CLI.png'),
        League(id: 2014, name: 'LaLiga', logo: 'https://crests.football-data.org/PD.png'),
        League(id: 2000, name: 'FIFA World Cup', logo: 'https://crests.football-data.org/WC.png'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CommonLayout(
      selectedIndex: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FutureBuilder<List<League>>(
                future: futureLeagues,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Hiba: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Nincs elérhető bajnokság'));
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final league = snapshot.data![index];
                      return LeagueTile(league: league);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LeagueTile extends StatelessWidget {
  final League league;

  const LeagueTile({super.key, required this.league});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LeagueDetailsPage(leagueId: league.id, leagueName: league.name),
          ),
        );
      },
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: _buildLogoImage(league.id, league.logo, isDarkMode),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                league.name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontFamily: 'Lexend',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Frissített segédfüggvény az online logók megjelenítéséhez
  Widget _buildLogoImage(int leagueId, String? logoUrl, bool isDarkMode) {
    // Online helyettesítő logó hivatkozások a problémás bajnokságokhoz
    Map<int, String> replacementLogos = {
      2013: 'https://upload.wikimedia.org/wikipedia/en/0/04/Campeonato_Brasileiro_S%C3%A9rie_A.png', // Brasileiro Série A
      2018: 'https://static.wikia.nocookie.net/future/images/8/84/Euro_2028_Logo_Concept_v2.png/revision/latest?cb=20231020120018', // European Championship
      2003: 'https://cdn.freelogovectors.net/wp-content/uploads/2021/08/eredivisie_logo-freelogovectors.net_.png', // Eredivisie
      2000: 'https://upload.wikimedia.org/wikipedia/en/thumb/1/17/2026_FIFA_World_Cup_emblem.svg/1200px-2026_FIFA_World_Cup_emblem.svg.png', // FIFA World Cup
      2015: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Ligue1_Uber_Eats_logo.png/640px-Ligue1_Uber_Eats_logo.png', // Ligue 1
      2019: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/Serie_A_logo_2022.svg/800px-Serie_A_logo_2022.svg.png', // Serie A
      2014: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/LaLiga_logo_2023.svg/2048px-LaLiga_logo_2023.svg.png', // LaLiga
      2021: 'https://b.fssta.com/uploads/application/soccer/competition-logos/EnglishPremierLeague.vresize.350.350.medium.0.png', // Premier League
      2152: 'https://upload.wikimedia.org/wikipedia/en/thumb/a/a1/Copa_Libertadores_logo.svg/800px-Copa_Libertadores_logo.svg.png', // Copa Libertadores
    };
    
    // Proxy használata a webes verzióban
    String getProxiedUrl(String url) {
      if (kIsWeb) {
        return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(url)}';
      }
      return url;
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
          headers: kIsWeb ? {'Origin': 'null'} : null,
          errorBuilder: (context, error, stackTrace) {
            print("Helyettesítő kép betöltési hiba (ID: $leagueId): $error");
            return Icon(
              Icons.sports_soccer, 
              size: 36,
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
        headers: kIsWeb ? {'Origin': 'null'} : null,
        errorBuilder: (context, error, stackTrace) {
          print("Helyettesítő kép betöltési hiba (ID: $leagueId): $error");
          return Icon(
            Icons.sports_soccer, 
            size: 36,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          );
        },
      );
    }
    
    // Premier League és Bajnokok Ligája esetén fehér szín sötét módban
    if ((leagueId == 2021 || leagueId == 2001) && isDarkMode) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
        child: _getNetworkImage(logoUrl, isDarkMode),
      );
    }
    
    // Minden más esetben az eredeti logót használjuk
    return _getNetworkImage(logoUrl, isDarkMode);
  }
  
  // Segédfüggvény a hálózati kép megjelenítéséhez
  Widget _getNetworkImage(String? logoUrl, bool isDarkMode) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Icon(
        Icons.sports_soccer, 
        size: 36,
        color: isDarkMode ? Colors.white70 : Colors.black54,
      );
    }
    
    // Proxy használata a webes verzióban
    String proxyUrl = logoUrl;
    if (kIsWeb) {
      proxyUrl = 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(logoUrl)}';
    }
    
    return Image.network(
      proxyUrl,
      fit: BoxFit.contain,
      headers: kIsWeb ? {'Origin': 'null'} : null,
      errorBuilder: (context, error, stackTrace) {
        print("Eredeti logó betöltési hiba: $error");
        return Icon(
          Icons.sports_soccer, 
          size: 36,
          color: isDarkMode ? Colors.white70 : Colors.black54,
        );
      },
    );
  }
}