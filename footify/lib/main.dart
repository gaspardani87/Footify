// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:footify/calendar.dart';
import 'package:footify/leagues.dart';
import 'package:footify/profile.dart';
import 'package:footify/settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'common_layout.dart';
// import 'web_plugin.dart' if (dart.library.html) 'web_plugin.dart';
// import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Import this package

// Define fetchData as a global variable
late Future<Map<String, dynamic>> Function() fetchData;

Future<Map<String, dynamic>> fetchDataDefault() async {
  final proxyUrl = 'https://thingproxy.freeboard.io/fetch/';
  final apiUrl = 'https://api.football-data.org/v4/matches';
  
  final response = await http.get(
    Uri.parse('$proxyUrl$apiUrl'),
    headers: {
      'X-Auth-Token': '4c553fac5d704101906782d1ecbe1b12',
    },
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to load data: ${response.statusCode} ${response.body}');
  }
}

void main() {
  // Assign the default fetchData function
  fetchData = fetchDataDefault;

  // Add this block to ensure proper initialization for desktop platforms
  if (kIsWeb || ![TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)) {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const HomePage());
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Lexend',
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: const Color(0xFFFFE6AC),
          unselectedItemColor: Colors.white,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>> _futureData = fetchData();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Widget page;
    switch (index) {
      case 0:
        page = const HomePage();
        break;
      case 1:
        page = const CalendarPage();
        break;
      case 2:
        page = const LeaguePage();
        break;
      case 3:
        page = const ProfilePage();
        break;
      case 4:
        page = const SettingsPage();
        break;
      default:
        page = const HomePage();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommonLayout(
      selectedIndex: _selectedIndex,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white,));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            if (data['matches'] == null || data['matches'].isEmpty) {
              return const Center(child: Text('No data available'));
            }
            return ListView.builder(
              itemCount: data['matches'].length,
              itemBuilder: (context, index) {
                final item = data['matches'][index];
                final homeTeam = item['homeTeam']['name'] ?? 'No home team available';
                final awayTeam = item['awayTeam']['name'] ?? 'No away team available';
                final resultInfo = item['score']['fullTime']['home'] != null && item['score']['fullTime']['away'] != null
                    ? '${item['score']['fullTime']['home']} - ${item['score']['fullTime']['away']}'
                    : 'No result yet';
                return ListTile(
                  title: Text('$homeTeam vs $awayTeam', style: const TextStyle(color: Colors.white),),
                  subtitle: Text(resultInfo, style: const TextStyle(color: Colors.white),
                ));
              },
            );
          } else {
            return const Center(child: Text('No data available'));
          }
        },
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(); // Empty container for now
  }
}

class CustomSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
        fontFamily: 'Lexend',
        appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1D1D1D), // Set the background color of the AppBar
        
      ),
      inputDecorationTheme: const InputDecorationTheme(
        
        hintStyle: TextStyle(color: Color.fromARGB(170, 240, 240, 240)), // Set the hint text color
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffe6ac), width: 3.0)), // Set the focused border color
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffe6ac), width: 1.7)), // Set the enabled border color 
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white), // Set the search text color
         // Set the cursor color
      ),

    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: Colors.white),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D1D1D), Color(0xFF292929)], // Replace with your desired colors
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Text(query, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? []
        : ['Suggestion 1', 'Suggestion 2', 'Suggestion 3']; // Replace with your own suggestions

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D1D1D), Color(0xFF292929)], // Replace with your desired colors
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(suggestions[index], style: const TextStyle(color: Colors.white)),
            onTap: () {
              query = suggestions[index];
              showResults(context);
            },
          );
        },
      ),
    );
  }
}