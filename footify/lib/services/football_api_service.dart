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
            return {
              'id': team['id']?.toString() ?? '',
              'name': team['name']?.toString() ?? 'Unknown Team',
              'crest': team['crest']?.toString() ?? '',
              'tla': team['tla']?.toString() ?? '',
            };
          }).toList().cast<Map<String, String>>();
        } else {
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
        if (data is Map && data.containsKey('competitions') && data['competitions'] is List) {
          List<dynamic> leaguesData = data['competitions'];
          return leaguesData.map((league) {
            return {
              'id': league['id']?.toString() ?? '',
              'name': league['name']?.toString() ?? 'Unknown League',
              'code': league['code']?.toString() ?? '',
              'emblem': league['emblem']?.toString() ?? '',
            };
          }).toList().cast<Map<String, String>>();
        } else {
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
} 