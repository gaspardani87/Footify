// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/foundation.dart'; // Add this import


void main() {
  // Add this block to ensure proper initialization for desktop platforms
  if (kIsWeb || ![TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform)) {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1D1D1D), Color(0xFF292929)], // Replace with your desired colors
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SvgPicture.asset(
                      'assets/images/Footify-Logo-NoBG_szerk_hosszu_logo_feher-01.svg',
                      width: 120,
                      height: 120,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Image.asset(
                          'assets/images/search-icon.png',
                          width: 30,
                          height: 30,
                        ),
                        onPressed: () {
                          showSearch(
                            context: context,
                            delegate: CustomSearchDelegate(),
                          );
                        },
                      ),
                      IconButton(
                        icon: Image.asset(
                          'assets/images/bell-icon.png',
                          width: 30,
                          height: 30,
                        ),
                        onPressed: () {
                          // Add your notification functionality here
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(
              color: Color(0xFFFFE6AC),
              thickness: 3,
            ),
            const Expanded(child: Header()),
          ],
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: const Color(0xFF1D1D1B),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFFFFE6AC),
          unselectedItemColor: Colors.white,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.help_outline),
              label: 'Unknown',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events),
              label: 'League',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
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