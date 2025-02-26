// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:footify/calendar.dart';
import 'package:footify/leagues.dart';
import 'package:footify/profile.dart';
import 'package:footify/settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'common_layout.dart';
import 'theme_provider.dart';

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
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const HomePage(),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        // Set font family and default text color for light theme
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Lexend',
              bodyColor: Colors.black, // Set default text color to black
              displayColor: Colors.black, // Set default text color to black
            ),
        appBarTheme: ThemeData.light().appBarTheme.copyWith(
              titleTextStyle: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Set AppBar text color to black
              ),
            ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: const Color(0xFFFFE6AC),
          unselectedItemColor: Colors.black,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        // Set font family and default text color for dark theme
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Lexend',
              bodyColor: Colors.white, // Set default text color to white
              displayColor: Colors.white, // Set default text color to white
            ),
        appBarTheme: ThemeData.dark().appBarTheme.copyWith(
              titleTextStyle: TextStyle(
                fontFamily: 'Lexend',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white, // Set AppBar text color to white
              ),
            ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: const Color(0xFFFFE6AC),
          unselectedItemColor: Colors.white,
        ),
      ),
      themeMode: themeProvider.themeMode, // Use the selected theme mode
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return CommonLayout(
      selectedIndex: _selectedIndex,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? Colors.white : Colors.black, // Set progress indicator color
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), // Set text color
              ),
            );
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            if (data['matches'] == null || data['matches'].isEmpty) {
              return Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), // Set text color
                ),
              );
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
                  title: Text(
                    '$homeTeam vs $awayTeam',
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), // Set text color
                  ),
                  subtitle: Text(
                    resultInfo,
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), // Set text color
                  ),
                );
              },
            );
          } else {
            return Center(
              child: Text(
                'No data available',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), // Set text color
              ),
            );
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ThemeData(
      fontFamily: 'Lexend',
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white, // Set AppBar background color
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDarkMode ? const Color.fromARGB(170, 240, 240, 240) : Colors.black54), // Set hint text color
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffe6ac), width: 3.0)), // Set focused border color
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffe6ac), width: 1.7)), // Set enabled border color
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: isDarkMode ? Colors.white : Colors.black), // Set search text color
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return [
      IconButton(
        icon: Icon(Icons.clear, color: isDarkMode ? Colors.white : Colors.black), // Set clear icon color
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black), // Set back arrow icon color
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF1D1D1D), const Color(0xFF292929)] // Dark mode gradient
              : [Colors.white, Colors.white], // Light mode gradient
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Text(
          query,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), // Set text color
        ),
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final suggestions = query.isEmpty
        ? []
        : ['Suggestion 1', 'Suggestion 2', 'Suggestion 3']; // Replace with your own suggestions

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF1D1D1D), const Color(0xFF292929)] // Dark mode gradient
              : [Colors.white, Colors.white], // Light mode gradient
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              suggestions[index],
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black), // Set text color
            ),
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