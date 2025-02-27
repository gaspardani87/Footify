import 'package:http/http.dart' as http;
import 'dart:convert';

class FootballApiService {
  static const String _baseUrl = 'https://api.football-data.org/v4';
  static const String _apiKey = '4c553fac5d704101906782d1ecbe1b12';
  static const String _proxyUrl = 'https://thingproxy.freeboard.io/fetch/';

  Future<List<Map<String, String>>> getTeams() async {
    final response = await http.get(
      Uri.parse('$_proxyUrl$_baseUrl/teams'),
      headers: {'X-Auth-Token': _apiKey},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['teams'] as List).map((team) => {
        'name': team['name'] as String,
        'crest': team['crest'] as String,
      }).toList();
    } else {
      throw Exception('Failed to load teams');
    }
  }

  Future<List<Map<String, String>>> getLeagues() async {
    final response = await http.get(
      Uri.parse('$_proxyUrl$_baseUrl/competitions'),
      headers: {'X-Auth-Token': _apiKey},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['competitions'] as List).map((league) => {
        'name': league['name'] as String,
        'emblem': league['emblem'] as String,
      }).toList();
    } else {
      throw Exception('Failed to load leagues');
    }
  }
} 