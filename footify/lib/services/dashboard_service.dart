import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A service to fetch data needed for the dashboard page
class DashboardService {
  // The base URL for Firebase Functions
  static const String _firebaseFunctionsBaseUrl = 'https://us-central1-footify-13da4.cloudfunctions.net';
  
  /// Get league standings for a specific league
  static Future<Map<String, dynamic>> getLeagueStandings(String leagueId) async {
    try {
      final String url = '$_firebaseFunctionsBaseUrl/fetchLeagueStandings?id=$leagueId';
      debugPrint('Requesting league standings from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched standings for league $leagueId');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load standings: ${response.statusCode}');
        return {
          'error': errorData['error'] ?? 'Failed to load standings', 
          'status': response.statusCode,
          'standings': [], 
        };
      }
    } catch (e) {
      debugPrint('Error getting league standings: $e');
      return {
        'error': e.toString(),
        'standings': [], 
      };
    }
  }
  
  /// Get team's league and standings
  static Future<Map<String, dynamic>> getTeamLeague(String teamId) async {
    try {
      final String url = '$_firebaseFunctionsBaseUrl/getTeamLeague?id=$teamId';
      debugPrint('Requesting team league info from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched league info for team $teamId');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load team league: ${response.statusCode}');
        return {
          'error': errorData['error'] ?? 'Failed to load team league', 
          'status': response.statusCode,
          'standings': null, 
        };
      }
    } catch (e) {
      debugPrint('Error getting team league: $e');
      return {
        'error': e.toString(),
        'standings': null, 
      };
    }
  }
  
  /// Get national team's competition and standings
  static Future<Map<String, dynamic>> getNationalTeamLeague(String teamId) async {
    try {
      final String url = '$_firebaseFunctionsBaseUrl/getNationalTeamLeague?id=$teamId';
      debugPrint('Requesting national team competition info from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched competition info for national team $teamId');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load national team competition: ${response.statusCode}');
        return {
          'error': errorData['error'] ?? 'Failed to load national team competition', 
          'status': response.statusCode,
          'standings': null, 
        };
      }
    } catch (e) {
      debugPrint('Error getting national team competition: $e');
      return {
        'error': e.toString(),
        'standings': null, 
      };
    }
  }
  
  /// Get next match for a specific team
  static Future<Map<String, dynamic>> getNextMatch(String teamId) async {
    try {
      final String url = '$_firebaseFunctionsBaseUrl/getNextMatch?id=$teamId';
      debugPrint('Requesting next match from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched next match for team $teamId');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load next match: ${response.statusCode}');
        return {
          'error': errorData['error'] ?? 'Failed to load next match', 
          'status': response.statusCode,
          'match': null, 
        };
      }
    } catch (e) {
      debugPrint('Error getting next match: $e');
      return {
        'error': e.toString(),
        'match': null, 
      };
    }
  }
  
  /// Get matches for a specific date
  static Future<Map<String, dynamic>> getMatchesByDate(String date) async {
    try {
      final String url = '$_firebaseFunctionsBaseUrl/getMatchesByDate?date=$date';
      debugPrint('Requesting matches for date from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      debugPrint('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched matches for date $date');
        
        // Debug match count
        if (data.containsKey('matches')) {
          final List matches = data['matches'] ?? [];
          debugPrint('Received ${matches.length} matches from API');
        } else {
          debugPrint('No matches field found in response');
        }
        
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load matches for date: ${response.statusCode}');
        debugPrint('Error details: ${errorData['error'] ?? 'Unknown error'}');
        return {
          'error': errorData['error'] ?? 'Failed to load matches', 
          'status': response.statusCode,
          'matches': [], 
        };
      }
    } catch (e) {
      debugPrint('Error getting matches by date: $e');
      return {
        'error': e.toString(),
        'matches': [], 
      };
    }
  }
  
  /// Get matches for a date range
  static Future<Map<String, dynamic>> getMatchesForDateRange(String dateFrom, String dateTo) async {
    try {
      final String url = '$_firebaseFunctionsBaseUrl/getMatchesForDateRange?dateFrom=$dateFrom&dateTo=$dateTo';
      debugPrint('Requesting matches for date range from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      debugPrint('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched matches for date range $dateFrom to $dateTo');
        debugPrint('Total matches: ${data['totalMatchCount'] ?? 0}');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load matches for date range: ${response.statusCode}');
        debugPrint('Error details: ${errorData['error'] ?? 'Unknown error'}');
        return {
          'error': errorData['error'] ?? 'Failed to load matches for date range', 
          'status': response.statusCode,
          'matchesByDate': {}, 
        };
      }
    } catch (e) {
      debugPrint('Error getting matches by date range: $e');
      return {
        'error': e.toString(),
        'matchesByDate': {}, 
      };
    }
  }
  
  /// Get upcoming matches, not limited to today
  static Future<Map<String, dynamic>> getUpcomingMatches() async {
    try {
      final String url = '$_firebaseFunctionsBaseUrl/getUpcomingMatches';
      debugPrint('Requesting upcoming matches from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched upcoming matches');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load upcoming matches: ${response.statusCode}');
        return {
          'error': errorData['error'] ?? 'Failed to load upcoming matches', 
          'status': response.statusCode,
          'matches': [], 
        };
      }
    } catch (e) {
      debugPrint('Error getting upcoming matches: $e');
      return {
        'error': e.toString(),
        'matches': [], 
      };
    }
  }
  
  /// Get national team's next match
  static Future<Map<String, dynamic>> getNationalTeamNextMatch(String teamId) async {
    try {
      final String url = '$_firebaseFunctionsBaseUrl/getNationalTeamNextMatch?id=$teamId';
      debugPrint('Requesting national team next match from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched next match for national team $teamId');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load national team next match: ${response.statusCode}');
        return {
          'error': errorData['error'] ?? 'Failed to load next match', 
          'status': response.statusCode,
          'match': null, 
        };
      }
    } catch (e) {
      debugPrint('Error getting national team next match: $e');
      return {
        'error': e.toString(),
        'match': null, 
      };
    }
  }
} 