// ignore_for_file: unused_element, deprecated_member_use, prefer_final_fields, library_private_types_in_public_api

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
import 'font_size_provider.dart';
import 'color_blind_mode_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/firebase_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'language_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  fetchData = fetchDataDefault;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontSizeProvider()),
        ChangeNotifierProvider(create: (_) => ColorBlindModeProvider()),
        ChangeNotifierProvider(create: (_) => FirebaseProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const HomePage(),
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context); // Add this

    return MaterialApp(
      title: 'Footify',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(ThemeData.light(), fontSizeProvider.fontSize, Provider.of<ColorBlindModeProvider>(context).isColorBlindMode),
      darkTheme: _buildTheme(ThemeData.dark(), fontSizeProvider.fontSize, Provider.of<ColorBlindModeProvider>(context).isColorBlindMode),
      themeMode: themeProvider.themeMode,
      locale: languageProvider.currentLocale, // Add this line
      localizationsDelegates: AppLocalizations.localizationsDelegates,  // Change this
      supportedLocales: AppLocalizations.supportedLocales,  // Change this
      home: const MainScreen(),
    );
  }

  // Helper function to build a theme with dynamic font size and color blind mode
  ThemeData _buildTheme(ThemeData baseTheme, double fontSize, bool isColorBlindMode) {
    final isDark = baseTheme.brightness == Brightness.dark;
    
    // Keep your existing color palettes
    final colorBlindPalette = isDark ? {
  // Dark Mode Adjustments
  'background': const Color(0xFF1A1A2F),  // Keep dark navy (good contrast)
  'surface': const Color(0xFF2A2A4A),     // Increased contrast from background
  'primary': const Color(0xFFF4D03F),     // Golden yellow (distinct from reds/greens)
  'secondary': const Color(0xFFE67E22),   // Pumpkin orange (differentiates from primary)
  'text': const Color(0xFFF9E79F),        // Pale yellow (high contrast)
  'textSecondary': const Color(0xFFF7DC6F), // Brighter yellow
  'accent': const Color(0xFF58D68D),      // Teal (visible to all CVD types)
  'divider': const Color(0xFFF1C40F),     // Bold yellow
  'button': const Color(0xFFF4D03F),      // Matches primary
} : {
  // Light Mode Adjustments
  'background': const Color(0xFFF8F9FA),  // Off-white
  'surface': const Color(0xFFE9ECEF),      // Light gray
  'primary': const Color(0xFF2E86C1),      // Perceptual blue (CVD-safe)
  'secondary': const Color(0xFF48C9B0),    // Teal (distinct from primary)
  'text': const Color(0xFF2C3E50),         // Dark navy (high contrast)
  'textSecondary': const Color(0xFF566573), // Medium slate
  'accent': const Color(0xFFE74C3C),       // Vermillion red (CVD-visible)
  'divider': const Color(0xFFAED6F1),      // Light blue
  'button': const Color(0xFF2E86C1),       // Matches primary
};

    final regularPalette = isDark ? {
      'background': const Color(0xFF1D1D1D),
      'surface': const Color(0xFF292929),
      'primary': const Color(0xFFFFE6AC),
      'secondary': const Color(0xFFFFE6AC).withOpacity(0.8),
      'text': Colors.white,
      'textSecondary': Colors.grey,
      'accent': const Color(0xFFFFE6AC),
      'divider': const Color(0xFFFFE6AC),
      'button': const Color(0xFFFFE6AC),
    } : {
      'background': Colors.white,
      'surface': Colors.grey[50]!,
      'primary': const Color(0xFFFFE6AC),
      'secondary': const Color(0xFFFFE6AC).withOpacity(0.8),
      'text': Colors.black,
      'textSecondary': Colors.black54,
      'accent': const Color(0xFFFFE6AC),
      'divider': Colors.black,
      'button': const Color(0xFFFFE6AC),
    };

    // Select the appropriate palette based on colorblind mode
    final colors = isColorBlindMode ? colorBlindPalette : regularPalette;

    // Apply the colors consistently throughout the theme
    return baseTheme.copyWith(
      scaffoldBackgroundColor: colors['background'],
      cardColor: colors['surface'],
      primaryColor: colors['primary'],
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: colors['primary']!,
        onPrimary: colors['text']!,
        secondary: colors['secondary']!,
        onSecondary: colors['text']!,
        error: Colors.red,
        onError: Colors.white,
        background: colors['background']!,
        onBackground: colors['text']!,
        surface: colors['surface']!,
        onSurface: colors['text']!,
      ),
      textTheme: _buildTextTheme(baseTheme.textTheme, fontSize).apply(
        bodyColor: colors['text'],
        displayColor: colors['text'],
      ),
      iconTheme: IconThemeData(color: colors['text']),
      primaryIconTheme: IconThemeData(color: colors['text']),
      appBarTheme: AppBarTheme(
        backgroundColor: colors['background'],
        iconTheme: IconThemeData(color: colors['text']),
        titleTextStyle: TextStyle(
          color: colors['text'],
          fontSize: fontSize * 1.25,
          fontFamily: 'Lexend',
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors['background'],
        selectedItemColor: colors['primary'],
        unselectedItemColor: colors['textSecondary'],
      ),
      dividerTheme: DividerThemeData(
        color: colors['divider'],
      ),
    );
  }

  // Helper function to build a TextTheme with the desired font size and Lexend font
  TextTheme _buildTextTheme(TextTheme baseTextTheme, double fontSize) {
    return baseTextTheme.copyWith(
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize * 1.25,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize * 1.15,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize * 1.05,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontFamily: 'Lexend',
        fontSize: fontSize,
      ),
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
  Map<String, bool> _expandedCompetitions = {};

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
    final colorScheme = Theme.of(context).colorScheme;

    return CommonLayout(
      selectedIndex: _selectedIndex,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            );
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            if (data['matches'] == null || data['matches'].isEmpty) {
              return Center(
                child: Text(
                  'No matches available',
                  style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                ),
              );
            }
            
            // Group matches by competition
            final Map<String, List<dynamic>> matchesByCompetition = {};
            
            for (var match in data['matches']) {
              final competitionName = match['competition']['name'] ?? 'Other Competitions';
              if (!matchesByCompetition.containsKey(competitionName)) {
                matchesByCompetition[competitionName] = [];
              }
              matchesByCompetition[competitionName]!.add(match);
            }
            
            // Sort competitions alphabetically
            final sortedCompetitions = matchesByCompetition.keys.toList()..sort();
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedCompetitions.length,
              itemBuilder: (context, index) {
                final competitionName = sortedCompetitions[index];
                final matches = matchesByCompetition[competitionName]!;
                
                return StatefulBuilder(
                  builder: (context, setState) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Competition header (clickable)
                          InkWell(
                            onTap: () {
                              setState(() {
                                // Toggle the expanded state for this competition
                                _expandedCompetitions[competitionName] = !(_expandedCompetitions[competitionName] ?? true);
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: (_expandedCompetitions[competitionName] ?? true) ? Radius.zero : const Radius.circular(12),
                                  bottomRight: (_expandedCompetitions[competitionName] ?? true) ? Radius.zero : const Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Trophy icon
                                  Icon(
                                    Icons.emoji_events,
                                    color: colorScheme.onPrimary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      competitionName,
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: (_expandedCompetitions[competitionName] ?? true) ? 0.0 : 0.5,
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(
                                      Icons.keyboard_arrow_up,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Animated matches list (collapsible)
                          AnimatedCrossFade(
                            firstChild: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: matches.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: colorScheme.onSurface.withOpacity(0.1),
                              ),
                              itemBuilder: (context, matchIndex) {
                                final match = matches[matchIndex];
                                final homeTeam = match['homeTeam']['name'] ?? 'Unknown Team';
                                final awayTeam = match['awayTeam']['name'] ?? 'Unknown Team';
                                final homeScore = match['score']['fullTime']['home'];
                                final awayScore = match['score']['fullTime']['away'];
                                final matchStatus = match['status'] ?? '';
                                final matchDate = DateTime.parse(match['utcDate']);
                                final formattedDate = '${matchDate.year}/${matchDate.month.toString().padLeft(2, '0')}/${matchDate.day.toString().padLeft(2, '0')}';
                                final formattedTime = '${matchDate.hour.toString().padLeft(2, '0')}:${matchDate.minute.toString().padLeft(2, '0')}';
                                
                                final scoreText = (homeScore != null && awayScore != null) 
                                    ? '$homeScore - $awayScore' 
                                    : 'vs';
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  child: Row(
                                    children: [
                                      // Match time/date
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              color: colorScheme.onSurface.withOpacity(0.7),
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              color: colorScheme.onSurface,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            matchStatus == 'FINISHED' 
                                                ? 'FINISHED'
                                                : matchStatus == 'IN_PLAY' 
                                                    ? 'LIVE'
                                                    : matchStatus,
                                            style: TextStyle(
                                              color: matchStatus == 'FINISHED' 
                                                  ? Colors.green 
                                                  : matchStatus == 'IN_PLAY' 
                                                      ? Colors.red 
                                                      : colorScheme.onSurface.withOpacity(0.7),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Match details
                                      Expanded(
                                        child: Row(
                                          children: [
                                            // Home team with badge on left
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  // Home team badge
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Image.network(
                                                      match['homeTeam']['crest'] ?? '',
                                                      width: 24,
                                                      height: 24,
                                                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Home team name
                                                  Expanded(
                                                    child: Text(
                                                      homeTeam,
                                                      style: TextStyle(
                                                        color: colorScheme.onSurface,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            // Score
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: matchStatus == 'FINISHED' 
                                                    ? colorScheme.primaryContainer
                                                    : colorScheme.surfaceVariant,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                scoreText,
                                                style: TextStyle(
                                                  color: matchStatus == 'FINISHED'
                                                      ? colorScheme.onPrimaryContainer
                                                      : colorScheme.onSurfaceVariant,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            
                                            // Away team with badge on right
                                            Expanded(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  // Away team name
                                                  Expanded(
                                                    child: Text(
                                                      awayTeam,
                                                      style: TextStyle(
                                                        color: colorScheme.onSurface,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      textAlign: TextAlign.end,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // Away team badge
                                                  ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Image.network(
                                                      match['awayTeam']['crest'] ?? '',
                                                      width: 24,
                                                      height: 24,
                                                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            secondChild: const SizedBox.shrink(),
                            crossFadeState: (_expandedCompetitions[competitionName] ?? true) 
                                ? CrossFadeState.showFirst 
                                : CrossFadeState.showSecond,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          } else {
            return Center(
              child: Text(
                'No data available',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            );
          }
        },
      ),
    );
  }

  String getScoreText(dynamic match) {
    final homeScore = match['score']['fullTime']['home'];
    final awayScore = match['score']['fullTime']['away'];
    
    if (homeScore != null && awayScore != null) {
      return '$homeScore - $awayScore';
    } else {
      return 'vs';
    }
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