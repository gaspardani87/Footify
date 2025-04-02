import 'dart:convert';
import 'package:http/http.dart' as http;

class FootballApiService {
  // Base URL for Firebase Functions
  static String baseUrl = '';
  static bool _initialized = false;

  // Initialize the service with your Firebase project ID
  static void initialize(String firebaseProjectId) {
    baseUrl = 'https://us-central1-$firebaseProjectId.cloudfunctions.net';
    _initialized = true;
    print('FootballApiService initialized with base URL: $baseUrl');
  }

  // Check if service is initialized before making API calls
  static void _checkInitialized() {
    if (!_initialized) {
      throw Exception('FootballApiService has not been initialized. Call initialize(firebaseProjectId) first.');
    }
  }

  // Get all matches
  static Future<Map<String, dynamic>> getMatches() async {
    _checkInitialized();
    try {
      final response = await http.get(Uri.parse('$baseUrl/fetchFootballData'))
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded. Please try again later.');
      } else {
        throw Exception('Failed to load matches: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getMatches: $e');
      throw Exception('Error fetching matches: $e');
    }
  }

  // Get specific match by ID with enhanced error handling
  static Future<Map<String, dynamic>> getMatchById(int matchId) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fetchMatchById').replace(
          queryParameters: {'id': matchId.toString()}
        )
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Match data retrieved successfully for match $matchId');
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Match not found');
      } else if (response.statusCode == 429) {
        throw Exception('API rate limit exceeded. Please try again later.');
      } else {
        print('API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load match: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getMatchById: $e');
      throw Exception('Error fetching match: $e');
    }
  }

  // Enhanced team matches API with better error handling and retry logic
  static Future<Map<String, dynamic>> getTeamMatches(
    int teamId, {
    String? status,
    String? dateFrom,
    String? dateTo,
    int limit = 10
  }) async {
    _checkInitialized();
    try {
      Map<String, String> queryParams = {
        'id': teamId.toString(),
        'limit': limit.toString(),
      };
      
      if (status != null) queryParams['status'] = status;
      if (dateFrom != null) queryParams['dateFrom'] = dateFrom;
      if (dateTo != null) queryParams['dateTo'] = dateTo;
      
      final response = await http.get(
        Uri.parse('$baseUrl/fetchTeamMatches').replace(
          queryParameters: queryParams
        )
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('matches')) {
          return data;
        } else {
          print('Invalid data format from team matches API for team $teamId');
          return {'matches': []};
        }
      } else if (response.statusCode == 429) {
        print('API rate limit exceeded for team $teamId');
        return {'matches': [], 'errorCode': 429, 'message': 'Rate limit exceeded'};
      } else {
        print('Team matches API error: ${response.statusCode} - ${response.body}');
        return {'matches': [], 'errorCode': response.statusCode};
      }
    } catch (e) {
      print('Error in getTeamMatches: $e');
      return {'matches': [], 'error': e.toString()};
    }
  }

  // New method to get head-to-head data for two teams
  static Future<Map<String, dynamic>> getHeadToHead(int team1Id, int team2Id, {int limit = 10}) async {
    _checkInitialized();
    try {
      // Get matches for the first team
      final team1Matches = await getTeamMatches(team1Id, limit: limit * 2);
      
      if (!team1Matches.containsKey('matches') || team1Matches['matches'] is! List) {
        return {'matches': []};
      }
      
      // Filter for matches against the second team
      final List<dynamic> allMatches = team1Matches['matches'];
      final List<dynamic> h2hMatches = allMatches.where((match) {
        final int homeTeamId = match['homeTeam']?['id'] ?? 0;
        final int awayTeamId = match['awayTeam']?['id'] ?? 0;
        return (homeTeamId == team1Id && awayTeamId == team2Id) || 
               (homeTeamId == team2Id && awayTeamId == team1Id);
      }).take(limit).toList();
      
      return {'matches': h2hMatches};
    } catch (e) {
      print('Error in getHeadToHead: $e');
      return {'matches': [], 'error': e.toString()};
    }
  }

  // New method to get detailed match statistics
  static Future<Map<String, dynamic>> getMatchStatistics(int matchId) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fetchMatchStatistics').replace(
          queryParameters: {'id': matchId.toString()}
        )
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Ensure we return a properly typed Map<String, dynamic>
        if (data is Map) {
          final Map<String, dynamic> typedData = {};
          data.forEach((key, value) {
            if (value is Map) {
              // Convert nested maps to Map<String, dynamic>
              final Map<String, dynamic> typedNestedMap = {};
              value.forEach((nestedKey, nestedValue) {
                typedNestedMap[nestedKey.toString()] = nestedValue;
              });
              typedData[key.toString()] = typedNestedMap;
            } else {
              typedData[key.toString()] = value;
            }
          });
          return typedData;
        }
        return {'statistics': {}};
      } else if (response.statusCode == 404) {
        print('Match statistics not found for match $matchId');
        return {'statistics': {}};
      } else if (response.statusCode == 429) {
        print('API rate limit exceeded when fetching match statistics');
        return {'statistics': {}, 'error': 'Rate limit exceeded'};
      } else {
        print('API error when fetching match statistics: ${response.statusCode}');
        return {'statistics': {}, 'error': 'Failed to load statistics'};
      }
    } catch (e) {
      print('Error in getMatchStatistics: $e');
      return {'statistics': {}, 'error': e.toString()};
    }
  }

  // Get proxied image URL
  static String getProxyImageUrl(String originalUrl) {
    _checkInitialized();
    return '$baseUrl/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
  }
  
  // Get all teams
  static Future<List<Map<String, String>>> getTeams() async {
    _checkInitialized();
    try {
      final response = await http.get(Uri.parse('$baseUrl/fetchTeams'))
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('teams') && data['teams'] is List) {
          List<dynamic> teamsData = data['teams'];
          return teamsData.map((team) {
            String crestUrl = team['crest']?.toString() ?? '';
            // Use proxy for non-direct images
            if (crestUrl.isNotEmpty && !crestUrl.startsWith('data:')) {
              crestUrl = '$baseUrl/proxyImage?url=${Uri.encodeComponent(crestUrl)}';
            }
            
            return {
              'id': team['id']?.toString() ?? '',
              'name': team['name']?.toString() ?? 'Unknown Team',
              'crest': crestUrl,
              'tla': team['tla']?.toString() ?? '',
            };
          }).toList().cast<Map<String, String>>();
        } else {
          print('Invalid team data format: $data');
          return [];
        }
      } else {
        print('Failed to load teams: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error in getTeams: $e');
      return [];
    }
  }
  
  // Get all leagues
  static Future<List<Map<String, String>>> getLeagues() async {
    _checkInitialized();
    try {
      final response = await http.get(Uri.parse('$baseUrl/fetchLeagues'))
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((league) {
            String emblemUrl = league['emblem']?.toString() ?? '';
            // Use proxy for non-direct images
            if (emblemUrl.isNotEmpty && !emblemUrl.startsWith('data:')) {
              emblemUrl = '$baseUrl/proxyImage?url=${Uri.encodeComponent(emblemUrl)}';
            }
            
            return {
              'id': league['id']?.toString() ?? '',
              'name': league['name']?.toString() ?? 'Unknown League',
              'crest': emblemUrl,
              'countryCode': league['code']?.toString() ?? '',
            };
          }).toList().cast<Map<String, String>>();
        } else {
          print('Invalid league data format: $data');
          return [];
        }
      } else {
        print('Failed to load leagues: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error in getLeagues: $e');
      return [];
    }
  }
  
  // Get national teams from API
  static Future<List<Map<String, dynamic>>> getNationalTeams({bool useFallback = false}) async {
    if (useFallback) {
      return _getFallbackNationalTeams();
    }

    try {
      _checkInitialized();
      final response = await http.get(Uri.parse('$baseUrl/fetchAreas'))
          .timeout(const Duration(seconds: 15));
          
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> areas = data['areas'] ?? [];
        
        print('API-tól kapott országok száma: ${areas.length}');
        
        // Filter for actual football countries (not continents), focusing on Europe & South America
        List<Map<String, dynamic>> nationalTeams = areas
            .where((area) {
              // Filter out continents and keep only countries
              bool isCountry = area['countryCode'] != null && 
                              area['countryCode'].toString().trim().isNotEmpty;
              
              // Focus on European and South American countries, or any with valid flag/country code
              return isCountry && 
                    (area['parentAreaId'] == 2 || // Europe
                     area['parentAreaId'] == 2077 || // South America
                     (area['flag'] != null && area['flag'].toString().trim().isNotEmpty));
            })
            .map<Map<String, dynamic>>((country) {
              // Ne használjuk a football-data zászlókat, inkább wikimedia-t
              String countryCode = country['countryCode']?.toString() ?? '';
              String flagUrl = '';
              String countryName = country['name']?.toString() ?? '';
              
              print('Feldolgozás: $countryName, kód: $countryCode');
              
              // Felhasználjuk a countryCode-ot, ha van, hogy megfelelő zászlót kapjunk
              if (countryCode.isNotEmpty) {
                // Wikimedia zászlók formátuma, country code alapján
                flagUrl = _getWikimediaFlagUrl(countryCode);
              }
              
              return {
                'name': countryName,
                'crest': flagUrl, // Közvetlen URL, proxy nélkül
                'id': country['id']?.toString() ?? '',
                'countryCode': countryCode,
              };
            })
            .toList();
        
        print('Szűrt országok száma: ${nationalTeams.length}');
        
        // If we got valid data, return it
        if (nationalTeams.isNotEmpty) {
          return nationalTeams;
        }
      }

      // If we got no valid data, use the fallback
      print('API adatok helyett fallback listák használata');
      return _getFallbackNationalTeams();
    } catch (e) {
      print('Error fetching national teams: $e');
      return _getFallbackNationalTeams();
    }
  }

  // Wikimedia zászló URL-eket ad vissza az ország kód alapján
  static String _getWikimediaFlagUrl(String countryCode) {
    // ISO kód átalakítása nagybetűssé
    countryCode = countryCode.toUpperCase();
    
    // 3 betűs országkódok konvertálása 2 betűsre
    if (countryCode.length == 3) {
      final Map<String, String> threeLetterToTwoLetter = {
        'BGR': 'BG',   // Bulgaria
        'DEU': 'DE',   // Germany
        'ESP': 'ES',   // Spain
        'GBR': 'GB',   // United Kingdom
        'FRA': 'FR',   // France
        'ITA': 'IT',   // Italy
        'BRA': 'BR',   // Brazil
        'ARG': 'AR',   // Argentina
        'NLD': 'NL',   // Netherlands
        'PRT': 'PT',   // Portugal
        'BEL': 'BE',   // Belgium
        'HUN': 'HU',   // Hungary
        'HRV': 'HR',   // Croatia
        'CHE': 'CH',   // Switzerland
        'SWE': 'SE',   // Sweden
        'POL': 'PL',   // Poland
        'UKR': 'UA',   // Ukraine
        'AUT': 'AT',   // Austria
        'CZE': 'CZ',   // Czech Republic
        'TUR': 'TR',   // Turkey
        'ROU': 'RO',   // Romania
        'IRL': 'IE',   // Ireland
        'SRB': 'RS',   // Serbia
        'GRC': 'GR',   // Greece
        'RUS': 'RU',   // Russia
        'SVK': 'SK',   // Slovakia
        'NOR': 'NO',   // Norway
        'MEX': 'MX',   // Mexico
        'DNK': 'DK',   // Denmark
        'JPN': 'JP',   // Japan
        'KOR': 'KR',   // South Korea
        'IRN': 'IR',   // Iran
        'SAU': 'SA',   // Saudi Arabia
        'AUS': 'AU',   // Australia
        'CAN': 'CA',   // Canada
        'EGY': 'EG',   // Egypt
        'MAR': 'MA',   // Morocco
        'NGA': 'NG',   // Nigeria
        'SEN': 'SN',   // Senegal
        'TUN': 'TN',   // Tunisia
        'CMR': 'CM',   // Cameroon
        'GHA': 'GH',   // Ghana
        'CIV': 'CI',   // Ivory Coast
        'LIE': 'LI',   // Liechtenstein
        'LUX': 'LU',   // Luxembourg
        'MCO': 'MC',   // Monaco
        'AND': 'AD',   // Andorra
        'SMR': 'SM',   // San Marino
        'MLT': 'MT',   // Malta
        'CYP': 'CY',   // Cyprus
        'ISL': 'IS',   // Iceland
        'FIN': 'FI',   // Finland
        'LVA': 'LV',   // Latvia
        'LTU': 'LT',   // Lithuania
        'EST': 'EE',   // Estonia
        'MDA': 'MD',   // Moldova
        'ALB': 'AL',   // Albania
        'MKD': 'MK',   // North Macedonia
        'BIH': 'BA',   // Bosnia and Herzegovina
        'MNE': 'ME',   // Montenegro
        'SVN': 'SI',   // Slovenia
        'BLR': 'BY',   // Belarus
        'ISR': 'IL',   // Israel
        'COL': 'CO',   // Colombia
        'PER': 'PE',   // Peru
        'CHL': 'CL',   // Chile
        'URY': 'UY',   // Uruguay
        'PRY': 'PY',   // Paraguay
        'ECU': 'EC',   // Ecuador
        'VEN': 'VE',   // Venezuela
        'BOL': 'BO',   // Bolivia
        'KEN': 'KE',   // Kenya
        'ZAF': 'ZA',   // South Africa
        'DZA': 'DZ',   // Algeria
        'AGO': 'AO',   // Angola
        'UGA': 'UG',   // Uganda
        'QAT': 'QA',   // Qatar
        'ARE': 'AE',   // United Arab Emirates
        'KWT': 'KW',   // Kuwait
        'JOR': 'JO',   // Jordan
        'OMN': 'OM',   // Oman
        'BHR': 'BH',   // Bahrain
        'LBN': 'LB',   // Lebanon
        'SYR': 'SY',   // Syria
        'IRQ': 'IQ',   // Iraq
        'AFG': 'AF',   // Afghanistan
        'PAK': 'PK',   // Pakistan
        'BGD': 'BD',   // Bangladesh
        'IND': 'IN',   // India
        'CHN': 'CN',   // China
        'THA': 'TH',   // Thailand
        'VNM': 'VN',   // Vietnam
        'IDN': 'ID',   // Indonesia
        'MYS': 'MY',   // Malaysia
        'PHL': 'PH',   // Philippines
        'NZL': 'NZ',   // New Zealand
      };
      
      if (threeLetterToTwoLetter.containsKey(countryCode)) {
        countryCode = threeLetterToTwoLetter[countryCode]!;
      } else {
        print('Ismeretlen 3 betűs országkód: $countryCode');
      }
    }
    
    // Speciális esetek kezelése
    if (countryCode == 'GB-ENG') {
      return 'https://upload.wikimedia.org/wikipedia/en/b/be/Flag_of_England.png';
    } else if (countryCode == 'GB-SCT') {
      return 'https://upload.wikimedia.org/wikipedia/commons/1/10/Flag_of_Scotland.png';
    } else if (countryCode == 'GB-WLS') {
      return 'https://upload.wikimedia.org/wikipedia/commons/d/dc/Flag_of_Wales.png';
    } else if (countryCode == 'GB-NIR') {
      return 'https://upload.wikimedia.org/wikipedia/commons/f/f6/Flag_of_Northern_Ireland.svg';
    }
    
    // Kész zászló URL-ek az egyes országokhoz
    final Map<String, String> flagUrls = {
      'DE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Flag_of_Germany.svg/800px-Flag_of_Germany.svg.png',
      'ES': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Flag_of_Spain.svg/800px-Flag_of_Spain.svg.png',
      'FR': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Flag_of_France.svg/800px-Flag_of_France.svg.png',
      'IT': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Flag_of_Italy.svg/800px-Flag_of_Italy.svg.png',
      'GB': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/Flag_of_the_United_Kingdom_(1-2).svg/800px-Flag_of_the_United_Kingdom_(1-2).svg.png',
      'US': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Flag_of_the_United_States.svg/800px-Flag_of_the_United_States.svg.png',
      'BR': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Flag_of_Brazil.svg/800px-Flag_of_Brazil.svg.png',
      'AR': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Flag_of_Argentina.svg/800px-Flag_of_Argentina.svg.png',
      'NL': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Flag_of_the_Netherlands.svg/800px-Flag_of_the_Netherlands.svg.png',
      'PT': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Flag_of_Portugal.svg/800px-Flag_of_Portugal.svg.png',
      'BE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Flag_of_Belgium.svg/800px-Flag_of_Belgium.svg.png',
      'HU': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Flag_of_Hungary.svg/800px-Flag_of_Hungary.svg.png',
      'HR': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Flag_of_Croatia.svg/800px-Flag_of_Croatia.svg.png',
      'CH': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Flag_of_Switzerland.svg/800px-Flag_of_Switzerland.svg.png',
      'SE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Flag_of_Sweden.svg/800px-Flag_of_Sweden.svg.png',
      'PL': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Flag_of_Poland.svg/800px-Flag_of_Poland.svg.png',
      'UA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Flag_of_Ukraine.svg/800px-Flag_of_Ukraine.svg.png',
      'AT': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Flag_of_Austria.svg/800px-Flag_of_Austria.svg.png',
      'CZ': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cb/Flag_of_the_Czech_Republic.svg/800px-Flag_of_the_Czech_Republic.svg.png',
      'TR': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Flag_of_Turkey.svg/800px-Flag_of_Turkey.svg.png',
      'RO': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Flag_of_Romania.svg/800px-Flag_of_Romania.svg.png',
      'IE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/45/Flag_of_Ireland.svg/800px-Flag_of_Ireland.svg.png',
      'RS': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/ff/Flag_of_Serbia.svg/800px-Flag_of_Serbia.svg.png',
      'GR': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Flag_of_Greece.svg/800px-Flag_of_Greece.svg.png',
      'RU': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f3/Flag_of_Russia.svg/800px-Flag_of_Russia.svg.png',
      'SK': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e6/Flag_of_Slovakia.svg/800px-Flag_of_Slovakia.svg.png',
      'NO': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d9/Flag_of_Norway.svg/800px-Flag_of_Norway.svg.png',
      'MX': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fc/Flag_of_Mexico.svg/800px-Flag_of_Mexico.svg.png',
      'DK': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9c/Flag_of_Denmark.svg/800px-Flag_of_Denmark.svg.png',
      'JP': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Flag_of_Japan.svg/800px-Flag_of_Japan.svg.png',
      'KR': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/09/Flag_of_South_Korea.svg/800px-Flag_of_South_Korea.svg.png',
      'IR': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/Flag_of_Iran.svg/800px-Flag_of_Iran.svg.png',
      'SA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0d/Flag_of_Saudi_Arabia.svg/800px-Flag_of_Saudi_Arabia.svg.png',
      'AU': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/88/Flag_of_Australia_(converted).svg/800px-Flag_of_Australia_(converted).svg.png',
      'CA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d9/Flag_of_Canada_(Pantone).svg/800px-Flag_of_Canada_(Pantone).svg.png',
      'EG': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Flag_of_Egypt.svg/800px-Flag_of_Egypt.svg.png',
      'MA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Flag_of_Morocco.svg/800px-Flag_of_Morocco.svg.png',
      'NG': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Flag_of_Nigeria.svg/800px-Flag_of_Nigeria.svg.png',
      'SN': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fd/Flag_of_Senegal.svg/800px-Flag_of_Senegal.svg.png',
      'TN': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ce/Flag_of_Tunisia.svg/800px-Flag_of_Tunisia.svg.png',
      'CM': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Flag_of_Cameroon.svg/800px-Flag_of_Cameroon.svg.png',
      'GH': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Flag_of_Ghana.svg/800px-Flag_of_Ghana.svg.png',
      'CI': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Flag_of_C%C3%B4te_d%27Ivoire.svg/800px-Flag_of_C%C3%B4te_d%27Ivoire.svg.png',
      'BG': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Flag_of_Bulgaria.svg/800px-Flag_of_Bulgaria.svg.png',
      'LI': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/Flag_of_Liechtenstein.svg/800px-Flag_of_Liechtenstein.svg.png',
      'LU': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/Flag_of_Luxembourg.svg/800px-Flag_of_Luxembourg.svg.png',
      'MC': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Flag_of_Monaco.svg/800px-Flag_of_Monaco.svg.png',
      'AD': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Flag_of_Andorra.svg/800px-Flag_of_Andorra.svg.png',
      'SM': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Flag_of_San_Marino.svg/800px-Flag_of_San_Marino.svg.png',
      'MT': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Flag_of_Malta.svg/800px-Flag_of_Malta.svg.png',
      'CY': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Flag_of_Cyprus.svg/800px-Flag_of_Cyprus.svg.png',
      'IS': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ce/Flag_of_Iceland.svg/800px-Flag_of_Iceland.svg.png',
      'FI': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Flag_of_Finland.svg/800px-Flag_of_Finland.svg.png',
      'LV': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Flag_of_Latvia.svg/800px-Flag_of_Latvia.svg.png',
      'LT': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Flag_of_Lithuania.svg/800px-Flag_of_Lithuania.svg.png',
      'EE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Flag_of_Estonia.svg/800px-Flag_of_Estonia.svg.png',
      'MD': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Flag_of_Moldova.svg/800px-Flag_of_Moldova.svg.png',
      'AL': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Flag_of_Albania.svg/800px-Flag_of_Albania.svg.png',
      'MK': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Flag_of_North_Macedonia.svg/800px-Flag_of_North_Macedonia.svg.png',
      'BA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bf/Flag_of_Bosnia_and_Herzegovina.svg/800px-Flag_of_Bosnia_and_Herzegovina.svg.png',
      'ME': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Flag_of_Montenegro.svg/800px-Flag_of_Montenegro.svg.png',
      'SI': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Flag_of_Slovenia.svg/800px-Flag_of_Slovenia.svg.png',
      'BY': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Flag_of_Belarus.svg/800px-Flag_of_Belarus.svg.png',
      'XK': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1f/Flag_of_Kosovo.svg/800px-Flag_of_Kosovo.svg.png',
      'IL': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Flag_of_Israel.svg/800px-Flag_of_Israel.svg.png',
      'CO': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/21/Flag_of_Colombia.svg/800px-Flag_of_Colombia.svg.png',
      'PE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Flag_of_Peru.svg/800px-Flag_of_Peru.svg.png',
      'CL': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/78/Flag_of_Chile.svg/800px-Flag_of_Chile.svg.png',
      'UY': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Flag_of_Uruguay.svg/800px-Flag_of_Uruguay.svg.png',
      'PY': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Flag_of_Paraguay.svg/800px-Flag_of_Paraguay.svg.png',
      'EC': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/Flag_of_Ecuador.svg/800px-Flag_of_Ecuador.svg.png',
      'VE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/06/Flag_of_Venezuela.svg/800px-Flag_of_Venezuela.svg.png',
      'BO': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/48/Flag_of_Bolivia.svg/800px-Flag_of_Bolivia.svg.png',
      'KE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Flag_of_Kenya.svg/800px-Flag_of_Kenya.svg.png',
      'ZA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Flag_of_South_Africa.svg/800px-Flag_of_South_Africa.svg.png',
      'DZ': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/77/Flag_of_Algeria.svg/800px-Flag_of_Algeria.svg.png',
      'AO': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Flag_of_Angola.svg/800px-Flag_of_Angola.svg.png',
      'UG': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Flag_of_Uganda.svg/800px-Flag_of_Uganda.svg.png',
      'QA': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Flag_of_Qatar.svg/800px-Flag_of_Qatar.svg.png',
      'AE': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cb/Flag_of_the_United_Arab_Emirates.svg/800px-Flag_of_the_United_Arab_Emirates.svg.png',
      'KW': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/aa/Flag_of_Kuwait.svg/800px-Flag_of_Kuwait.svg.png',
      'JO': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Flag_of_Jordan.svg/800px-Flag_of_Jordan.svg.png',
      'OM': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Flag_of_Oman.svg/800px-Flag_of_Oman.svg.png',
      'BH': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Flag_of_Bahrain.svg/800px-Flag_of_Bahrain.svg.png',
      'LB': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Flag_of_Lebanon.svg/800px-Flag_of_Lebanon.svg.png',
      'SY': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/53/Flag_of_Syria.svg/800px-Flag_of_Syria.svg.png',
      'IQ': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f6/Flag_of_Iraq.svg/800px-Flag_of_Iraq.svg.png',
      'AF': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Flag_of_the_Taliban.svg/800px-Flag_of_the_Taliban.svg.png',
      'PK': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/32/Flag_of_Pakistan.svg/800px-Flag_of_Pakistan.svg.png',
      'BD': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f9/Flag_of_Bangladesh.svg/800px-Flag_of_Bangladesh.svg.png',
      'IN': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/Flag_of_India.svg/800px-Flag_of_India.svg.png',
      'CN': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Flag_of_the_People%27s_Republic_of_China.svg/800px-Flag_of_the_People%27s_Republic_of_China.svg.png',
      'TH': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Flag_of_Thailand.svg/800px-Flag_of_Thailand.svg.png',
      'VN': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/21/Flag_of_Vietnam.svg/800px-Flag_of_Vietnam.svg.png',
      'ID': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/Flag_of_Indonesia.svg/800px-Flag_of_Indonesia.svg.png',
      'MY': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/Flag_of_Malaysia.svg/800px-Flag_of_Malaysia.svg.png',
      'PH': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/Flag_of_the_Philippines.svg/800px-Flag_of_the_Philippines.svg.png',
      'NZ': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/800px-Flag_of_New_Zealand.svg.png',
    };
    
    // Ha az országkód szerepel a közvetlen URL-ek között, azt használjuk
    if (flagUrls.containsKey(countryCode)) {
      return flagUrls[countryCode]!;
    }
    
    // Ha nincs találat, fallback zászló
    print('Nincs megfelelő zászló URL a következő országkódhoz: $countryCode');
    return 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/Flag_of_the_United_Nations.svg/800px-Flag_of_the_United_Nations.svg.png';
  }

  static List<Map<String, dynamic>> _getFallbackNationalTeams() {
    // Hardcoded list of key football nations with their flags (using wikimedia URLs)
    return [
      {
        'name': 'Hungary',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Flag_of_Hungary.svg/800px-Flag_of_Hungary.svg.png',
        'id': '825',
        'countryCode': 'HU'
      },
      {
        'name': 'Germany',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/ba/Flag_of_Germany.svg/800px-Flag_of_Germany.svg.png',
        'id': '759',
        'countryCode': 'DE'
      },
      {
        'name': 'Spain',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Flag_of_Spain.svg/800px-Flag_of_Spain.svg.png',
        'id': '760',
        'countryCode': 'ES'
      },
      {
        'name': 'England',
        'crest': 'https://upload.wikimedia.org/wikipedia/en/b/be/Flag_of_England.png',
        'id': '770',
        'countryCode': 'GB-ENG'
      },
      {
        'name': 'Brazil',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Flag_of_Brazil.svg/800px-Flag_of_Brazil.svg.png',
        'id': '764',
        'countryCode': 'BR'
      },
      {
        'name': 'Argentina',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Flag_of_Argentina.svg/800px-Flag_of_Argentina.svg.png',
        'id': '762',
        'countryCode': 'AR'
      },
      {
        'name': 'France',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Flag_of_France.svg/800px-Flag_of_France.svg.png',
        'id': '773',
        'countryCode': 'FR'
      },
      {
        'name': 'Italy',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Flag_of_Italy.svg/800px-Flag_of_Italy.svg.png',
        'id': '784',
        'countryCode': 'IT'
      },
      {
        'name': 'Netherlands',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/20/Flag_of_the_Netherlands.svg/800px-Flag_of_the_Netherlands.svg.png',
        'id': '785',
        'countryCode': 'NL'
      },
      {
        'name': 'Portugal',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Flag_of_Portugal.svg/800px-Flag_of_Portugal.svg.png',
        'id': '765',
        'countryCode': 'PT'
      },
      {
        'name': 'Belgium',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/Flag_of_Belgium.svg/800px-Flag_of_Belgium.svg.png',
        'id': '805',
        'countryCode': 'BE'
      },
      {
        'name': 'Croatia',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Flag_of_Croatia.svg/800px-Flag_of_Croatia.svg.png',
        'id': '799',
        'countryCode': 'HR'
      },
      {
        'name': 'Bulgaria',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9a/Flag_of_Bulgaria.svg/800px-Flag_of_Bulgaria.svg.png',
        'id': '9566',
        'countryCode': 'BG'
      },
      {
        'name': 'Liechtenstein',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/47/Flag_of_Liechtenstein.svg/800px-Flag_of_Liechtenstein.svg.png',
        'id': '9567',
        'countryCode': 'LI'
      },
      {
        'name': 'Luxembourg',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/Flag_of_Luxembourg.svg/800px-Flag_of_Luxembourg.svg.png',
        'id': '805',
        'countryCode': 'LU'
      },
      {
        'name': 'Monaco',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ea/Flag_of_Monaco.svg/800px-Flag_of_Monaco.svg.png',
        'id': '805',
        'countryCode': 'MC'
      },
      {
        'name': 'Andorra',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Flag_of_Andorra.svg/800px-Flag_of_Andorra.svg.png',
        'id': '805',
        'countryCode': 'AD'
      },
      {
        'name': 'San Marino',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b1/Flag_of_San_Marino.svg/800px-Flag_of_San_Marino.svg.png',
        'id': '805',
        'countryCode': 'SM'
      },
      {
        'name': 'Malta',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Flag_of_Malta.svg/800px-Flag_of_Malta.svg.png',
        'id': '805',
        'countryCode': 'MT'
      },
      {
        'name': 'Cyprus',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Flag_of_Cyprus.svg/800px-Flag_of_Cyprus.svg.png',
        'id': '805',
        'countryCode': 'CY'
      },
      {
        'name': 'Iceland',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ce/Flag_of_Iceland.svg/800px-Flag_of_Iceland.svg.png',
        'id': '805',
        'countryCode': 'IS'
      },
      {
        'name': 'Finland',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Flag_of_Finland.svg/800px-Flag_of_Finland.svg.png',
        'id': '805',
        'countryCode': 'FI'
      },
      {
        'name': 'Latvia',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/84/Flag_of_Latvia.svg/800px-Flag_of_Latvia.svg.png',
        'id': '805',
        'countryCode': 'LV'
      },
      {
        'name': 'Lithuania',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/11/Flag_of_Lithuania.svg/800px-Flag_of_Lithuania.svg.png',
        'id': '805',
        'countryCode': 'LT'
      },
      {
        'name': 'Estonia',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Flag_of_Estonia.svg/800px-Flag_of_Estonia.svg.png',
        'id': '805',
        'countryCode': 'EE'
      },
      {
        'name': 'Moldova',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/27/Flag_of_Moldova.svg/800px-Flag_of_Moldova.svg.png',
        'id': '805',
        'countryCode': 'MD'
      },
      {
        'name': 'Albania',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/36/Flag_of_Albania.svg/800px-Flag_of_Albania.svg.png',
        'id': '805',
        'countryCode': 'AL'
      },
      {
        'name': 'North Macedonia',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Flag_of_North_Macedonia.svg/800px-Flag_of_North_Macedonia.svg.png',
        'id': '805',
        'countryCode': 'MK'
      },
      {
        'name': 'Bosnia and Herzegovina',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bf/Flag_of_Bosnia_and_Herzegovina.svg/800px-Flag_of_Bosnia_and_Herzegovina.svg.png',
        'id': '805',
        'countryCode': 'BA'
      },
      {
        'name': 'Montenegro',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Flag_of_Montenegro.svg/800px-Flag_of_Montenegro.svg.png',
        'id': '805',
        'countryCode': 'ME'
      },
      {
        'name': 'Slovenia',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/f/f0/Flag_of_Slovenia.svg/800px-Flag_of_Slovenia.svg.png',
        'id': '805',
        'countryCode': 'SI'
      },
      {
        'name': 'Belarus',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Flag_of_Belarus.svg/800px-Flag_of_Belarus.svg.png',
        'id': '805',
        'countryCode': 'BY'
      },
      {
        'name': 'Kosovo',
        'crest': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1f/Flag_of_Kosovo.svg/800px-Flag_of_Kosovo.svg.png',
        'id': '805',
        'countryCode': 'XK'
      },
      // További országokat a második tömbben tartjuk meg egyszerűsítés céljából
    ];
  }

  // Search matches by query
  static Future<List<Map<String, dynamic>>> searchMatches(String query) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/searchMatches').replace(
          queryParameters: {'query': query}
        )
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((match) => {
            'id': match['id'],
            'name': '${match['homeTeam']['name']} vs ${match['awayTeam']['name']}',
            'homeTeam': match['homeTeam']['name'],
            'awayTeam': match['awayTeam']['name'],
            'competition': match['competition']['name'],
            'date': match['utcDate'],
            'status': match['status'],
            'score': match['score'],
            'type': 'match',
          }).toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      print('Error in searchMatches: $e');
      return [];
    }
  }

  // Search teams by query
  static Future<List<Map<String, dynamic>>> searchTeams(String query) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/searchTeams').replace(
          queryParameters: {'query': query}
        )
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((team) => {
            'id': team['id'],
            'name': team['name'],
            'emblem': team['crest'],
            'type': 'team',
          }).toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      print('Error in searchTeams: $e');
      return [];
    }
  }

  // Search competitions by query
  static Future<List<Map<String, dynamic>>> searchCompetitions(String query) async {
    _checkInitialized();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/searchCompetitions').replace(
          queryParameters: {'query': query}
        )
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((competition) => {
            'id': competition['id'],
            'name': competition['name'],
            'emblem': competition['emblem'],
            'type': 'competition',
          }).toList();
        }
        return [];
      }
      return [];
    } catch (e) {
      print('Error in searchCompetitions: $e');
      return [];
    }
  }
} 