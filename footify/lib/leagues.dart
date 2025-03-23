import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'common_layout.dart';
import 'league_details.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

    return League(
      id: json['id'],
      name: json['name'] ?? 'Unknown league',
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
        League(id: 2014, name: 'La Liga', logo: 'https://crests.football-data.org/PD.png'),
        League(id: 2000, name: 'FIFA World Cup', logo: 'https://crests.football-data.org/WC.png'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Get screen width for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    // Use 2 columns for small screens, more for larger screens
    final crossAxisCount = screenWidth < 600 ? 2 : screenWidth < 1200 ? 3 : 5;

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
                    return Center(child: Text(
                      '${AppLocalizations.of(context)!.errorFetchingLeagues}'.replaceAll('{error}', '${snapshot.error}')
                    ));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text(AppLocalizations.of(context)!.failedToLoadLeagues));
                  }

                  // Get original leagues list
                  List<League> originalLeagues = snapshot.data!;
                  
                  // Create a modified list that includes null placeholders for centering
                  List<League?> centeredLeagues = [];
                  
                  // Calculate how many complete rows we have
                  int totalItems = originalLeagues.length;
                  int completeRows = totalItems ~/ crossAxisCount;
                  int itemsInCompleteRows = completeRows * crossAxisCount;
                  
                  // How many items in the last row
                  int itemsInLastRow = totalItems - itemsInCompleteRows;
                  
                  // Add all items from complete rows
                  for (int i = 0; i < itemsInCompleteRows; i++) {
                    centeredLeagues.add(originalLeagues[i]);
                  }
                  
                  // If we have a partial last row, center it by adding null placeholders
                  if (itemsInLastRow > 0) {
                    // Calculate padding needed on each side to center
                    int leadingPadding = (crossAxisCount - itemsInLastRow) ~/ 2;
                    
                    // Add leading placeholders
                    for (int i = 0; i < leadingPadding; i++) {
                      centeredLeagues.add(null);
                    }
                    
                    // Add actual items for last row
                    for (int i = 0; i < itemsInLastRow; i++) {
                      centeredLeagues.add(originalLeagues[itemsInCompleteRows + i]);
                    }
                    
                    // Add trailing placeholders
                    for (int i = 0; i < leadingPadding; i++) {
                      centeredLeagues.add(null);
                    }
                    
                    // If odd number of padding needed, add one more at the end
                    if ((crossAxisCount - itemsInLastRow) % 2 != 0) {
                      centeredLeagues.add(null);
                    }
                  }
                  
                  // Now build the GridView with centered items
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: centeredLeagues.length,
                    itemBuilder: (context, index) {
                      // Return empty container for null placeholders
                      if (centeredLeagues[index] == null) {
                        return Container();
                      }
                      
                      // Return league tile for actual items
                      return LeagueTile(league: centeredLeagues[index]!);
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
    // Use screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
            // Adaptive padding based on screen size
            padding: EdgeInsets.all(isSmallScreen ? 10.0 : 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      // Adaptive size based on screen width
                      width: isSmallScreen ? 80 : 60,
                      height: isSmallScreen ? 80 : 60,
                      child: _buildLogoImage(league.id, league.logo, isDarkMode, !isSmallScreen),
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
                    fontSize: isSmallScreen ? 13 : 12,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontFamily: 'Lexend',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
}