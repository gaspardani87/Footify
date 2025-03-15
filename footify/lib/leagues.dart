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

    return League(
      id: json['id'],
      name: json['name'] ?? 'Ismeretlen bajnokság',
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
    // Webes vagy mobil platform ellenőrzése a kIsWeb segítségével
    final isWeb = kIsWeb;

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

                  // Csak webes verzióban igazítjuk középre az utolsó sor 3 elemét
                  if (isWeb) {
                    // Eredeti bajnokság lista
                    List<League> originalLeagues = snapshot.data!;
                    // Új lista a középre igazított megjelenítéshez
                    List<League?> modifiedLeagues = [];
                    
                    // A teljes sorok száma (5 elem soronként)
                    int completeRows = originalLeagues.length ~/ 5;
                    // A teljes sorokban lévő elemek
                    int completeRowElements = completeRows * 5;
                    // A maradék elemek száma
                    int remainingElements = originalLeagues.length - completeRowElements;
                    
                    // Teljes sorok hozzáadása
                    for (int i = 0; i < completeRowElements; i++) {
                      modifiedLeagues.add(originalLeagues[i]);
                    }
                    
                    // Az utolsó sor elemei középre igazítva
                    // Kiszámítjuk hány üres elem kell az utolsó sor elején
                    int leadingEmptySlots = (5 - remainingElements) ~/ 2;
                    
                    // Üres helyőrzők hozzáadása az elejére
                    for (int i = 0; i < leadingEmptySlots; i++) {
                      modifiedLeagues.add(null);
                    }
                    
                    // A maradék elemek hozzáadása
                    for (int i = completeRowElements; i < originalLeagues.length; i++) {
                      modifiedLeagues.add(originalLeagues[i]);
                    }
                    
                    // Üres helyőrzők hozzáadása a végére
                    for (int i = 0; i < leadingEmptySlots; i++) {
                      modifiedLeagues.add(null);
                    }
                    
                    // GridView építése a módosított listával
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: modifiedLeagues.length,
                      itemBuilder: (context, index) {
                        // Ha null (üres helyőrző), akkor üres Container-t adunk vissza
                        if (modifiedLeagues[index] == null) {
                          return Container();
                        }
                        // Egyébként megjelenítjük a ligát
                        return LeagueTile(league: modifiedLeagues[index]!);
                      },
                    );
                  } else {
                    // Mobil verzióban marad az eredeti elrendezés
                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                  }
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
    // Web vagy mobil platform ellenőrzése
    final isWeb = kIsWeb;
    
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
          // Webes verzióban kisebb padding
          padding: EdgeInsets.all(isWeb ? 8.0 : 10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    // Webes felületen kisebb méretű SizedBox a logóknak
                    width: isWeb ? 60 : 80,
                    height: isWeb ? 60 : 80,
                    child: _buildLogoImage(league.id, league.logo, isDarkMode, isWeb),
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
                  fontSize: isWeb ? 12 : 13,  // Webes verzióban kisebb betűméret
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