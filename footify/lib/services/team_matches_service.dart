import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A service to fetch team matches optimized for the calendar view
class TeamMatchesService {
  // The base URL for Firebase Functions
  static const String _firebaseFunctionsBaseUrl = 'https://us-central1-footify-13da4.cloudfunctions.net';
  
  /// Get the endpoint URL for a team's matches (useful for debugging)
  static String getEndpointUrl(String teamId) {
    return '$_firebaseFunctionsBaseUrl/fetchCalendarTeamMatches?id=$teamId';
  }
  
  /// Get matches for a specific team optimized for calendar display
  static Future<Map<String, dynamic>> getTeamMatches(String teamId) async {
    try {
      // Use the dedicated calendar matches endpoint
      final String url = getEndpointUrl(teamId);
      debugPrint('Requesting calendar matches from Firebase: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 15), // Add a timeout to prevent UI hanging
        onTimeout: () {
          throw Exception('Request timed out. Please check your connection and try again.');
        },
      );

      debugPrint('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Successfully fetched ${data['count']} matches for team $teamId');
        return data;
      } else {
        final errorData = json.decode(response.body);
        debugPrint('Failed to load matches: ${response.statusCode}');
        debugPrint('Error response: ${response.body}');
        return {
          'error': errorData['error'] ?? 'Failed to load matches', 
          'status': response.statusCode,
          'matches': [], // Empty array so the app doesn't crash
        };
      }
    } catch (e) {
      debugPrint('Error getting team matches: $e');
      return {
        'error': e.toString(),
        'matches': [], // Empty array so the app doesn't crash
      };
    }
  }
} 