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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:http/io_client.dart';


// Define fetchData as a global variable
late Future<Map<String, dynamic>> Function() fetchData;

Future<Map<String, dynamic>> fetchDataFirebase() async {
  const String url = 'https://us-central1-footify-13da4.cloudfunctions.net/fetchFootballData';
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed: ${response.statusCode} - ${response.body}');
    }
  } on http.ClientException catch (e) {
    print('ClientException: ${e.message}, URI: ${e.uri}');
    throw Exception('ClientException: Failed to fetch data - ${e.message}');
  } catch (e) {
    print('Error: $e');
    throw Exception('Error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  fetchData = fetchDataFirebase;

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
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      title: 'Footify',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(ThemeData.light(), fontSizeProvider.fontSize, Provider.of<ColorBlindModeProvider>(context).isColorBlindMode),
      darkTheme: _buildTheme(ThemeData.dark(), fontSizeProvider.fontSize, Provider.of<ColorBlindModeProvider>(context).isColorBlindMode),
      themeMode: themeProvider.themeMode,
      locale: languageProvider.currentLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainScreen(),
    );
  }

  // Helper function to build a theme with dynamic font size and color blind mode
  ThemeData _buildTheme(ThemeData baseTheme, double fontSize, bool isColorBlindMode) {
    final isDark = baseTheme.brightness == Brightness.dark;
    
    final colorBlindPalette = isDark ? {
      'background': const Color(0xFF1A1A2F),
      'surface': const Color(0xFF2A2A4A),
      'primary': const Color(0xFFF4D03F),
      'secondary': const Color(0xFFE67E22),
      'text': const Color(0xFFF9E79F),
      'textSecondary': const Color(0xFFF7DC6F),
      'accent': const Color(0xFF58D68D),
      'divider': const Color(0xFFF1C40F),
      'button': const Color(0xFFF4D03F),
    } : {
      'background': const Color(0xFFF8F9FA),
      'surface': const Color(0xFFE9ECEF),
      'primary': const Color(0xFF2E86C1),
      'secondary': const Color(0xFF48C9B0),
      'text': const Color(0xFF2C3E50),
      'textSecondary': const Color(0xFF566573),
      'accent': const Color(0xFFE74C3C),
      'divider': const Color(0xFFAED6F1),
      'button': const Color(0xFF2E86C1),
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

    final colors = isColorBlindMode ? colorBlindPalette : regularPalette;

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

  TextTheme _buildTextTheme(TextTheme baseTextTheme, double fontSize) {
    return baseTextTheme.copyWith(
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontFamily: 'Lexend', fontSize: fontSize),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontFamily: 'Lexend', fontSize: fontSize),
      bodySmall: baseTextTheme.bodySmall?.copyWith(fontFamily: 'Lexend', fontSize: fontSize),
      titleLarge: baseTextTheme.titleLarge?.copyWith(fontFamily: 'Lexend', fontSize: fontSize * 1.25),
      titleMedium: baseTextTheme.titleMedium?.copyWith(fontFamily: 'Lexend', fontSize: fontSize * 1.15),
      titleSmall: baseTextTheme.titleSmall?.copyWith(fontFamily: 'Lexend', fontSize: fontSize * 1.05),
      labelLarge: baseTextTheme.labelLarge?.copyWith(fontFamily: 'Lexend', fontSize: fontSize),
      labelMedium: baseTextTheme.labelMedium?.copyWith(fontFamily: 'Lexend', fontSize: fontSize),
      labelSmall: baseTextTheme.labelSmall?.copyWith(fontFamily: 'Lexend', fontSize: fontSize),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late Future<Map<String, dynamic>> _futureData = fetchData();
  Map<String, bool> _expandedCompetitions = {};
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_blinkController);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

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
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  String getProxiedImageUrl(String? originalUrl) {
  if (originalUrl == null || originalUrl.isEmpty) return '';
  if (kIsWeb) {
    // Proxy through Firebase function for web
    return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
  }
  // Use direct URL for mobile
  return originalUrl;
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
            return Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.white : Colors.black));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
          } else if (snapshot.hasData) {
            final data = snapshot.data!;
            if (data['matches'] == null || data['matches'].isEmpty) {
              return Center(child: Text('No matches available', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
            }
            
            final Map<String, List<dynamic>> matchesByCompetition = {};
            for (var match in data['matches']) {
              final competitionName = match['competition']['name'] ?? 'Other Competitions';
              if (!matchesByCompetition.containsKey(competitionName)) {
                matchesByCompetition[competitionName] = [];
              }
              matchesByCompetition[competitionName]!.add(match);
            }
            
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: colorScheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
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
                                  Icon(Icons.emoji_events, color: Colors.black, size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      competitionName,
                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                  AnimatedRotation(
                                    turns: (_expandedCompetitions[competitionName] ?? true) ? 0.0 : 0.5,
                                    duration: const Duration(milliseconds: 300),
                                    child: Icon(Icons.keyboard_arrow_up, color: Colors.black),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            height: (_expandedCompetitions[competitionName] ?? true) ? null : 0,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: (_expandedCompetitions[competitionName] ?? true) ? 1.0 : 0.0,
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: matches.length,
                                  separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
                                  itemBuilder: (context, matchIndex) {
                                    final match = matches[matchIndex];
                                    final homeTeam = match['homeTeam']['name'] ?? 'Unknown Team';
                                    final awayTeam = match['awayTeam']['name'] ?? 'Unknown Team';
                                    final homeScore = match['score']['fullTime']['home'];
                                    final awayScore = match['score']['fullTime']['away'];
                                    final matchStatus = match['status'] ?? '';
                                    final matchDate = DateTime.parse(match['utcDate']).add(const Duration(hours: 1));
                                    final formattedDate = '${matchDate.year}/${matchDate.month.toString().padLeft(2, '0')}/${matchDate.day.toString().padLeft(2, '0')}';
                                    final formattedTime = '${matchDate.hour.toString().padLeft(2, '0')}:${matchDate.minute.toString().padLeft(2, '0')}';
                                    final scoreText = (homeScore != null && awayScore != null) ? '$homeScore - $awayScore' : 'vs';
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(flex: 1, child: Text(formattedDate, style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7), fontSize: 12))),
                                              Expanded(flex: 1, child: Text(formattedTime, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center)),
                                              Expanded(
                                                flex: 1,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    if (matchStatus == 'IN_PLAY')
                                                      Padding(
                                                        padding: const EdgeInsets.only(right: 4.0),
                                                        child: FadeTransition(
                                                          opacity: _blinkAnimation,
                                                          child: Container(
                                                            width: 8,
                                                            height: 8,
                                                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                                          ),
                                                        ),
                                                      ),
                                                    Text(
                                                      matchStatus == 'FINISHED' ? 'FINISHED' : matchStatus == 'IN_PLAY' ? 'LIVE' : matchStatus == 'TIMED' ? 'UPCOMING' : matchStatus,
                                                      style: TextStyle(
                                                        color: matchStatus == 'FINISHED' ? Colors.green : matchStatus == 'IN_PLAY' ? Colors.red : colorScheme.onSurface.withOpacity(0.7),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Image.network(
                                                        getProxiedImageUrl(match['homeTeam']['crest']),
                                                        width: 24,
                                                        height: 24,
                                                        headers: kIsWeb ? {'Origin': 'null'} : {'User-Agent': 'Mozilla/5.0'},
                                                        errorBuilder: (context, error, stackTrace) => Container(
                                                          width: 24,
                                                          height: 24,
                                                          decoration: BoxDecoration(color: colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(4)),
                                                          child: Icon(Icons.sports_soccer, size: 16, color: colorScheme.onSurface),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(child: Text(homeTeam, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                                decoration: BoxDecoration(
                                                  color: matchStatus == 'FINISHED' ? colorScheme.primaryContainer : colorScheme.surfaceVariant,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  scoreText,
                                                  style: TextStyle(
                                                    color: scoreText == 'vs' ? (isDarkMode ? Colors.white : Colors.black) : (matchStatus == 'IN_PLAY' && isDarkMode ? Colors.white : Colors.black),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    Expanded(child: Text(awayTeam, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                                                    const SizedBox(width: 8),
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: Image.network(
                                                        getProxiedImageUrl(match['awayTeam']['crest']),
                                                        width: 24,
                                                        height: 24,
                                                        headers: kIsWeb ? {'Origin': 'null'} : {'User-Agent': 'Mozilla/5.0'},
                                                        errorBuilder: (context, error, stackTrace) => Container(
                                                          width: 24,
                                                          height: 24,
                                                          decoration: BoxDecoration(color: colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(4)),
                                                          child: Icon(Icons.sports_soccer, size: 16, color: colorScheme.onSurface),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          } else {
            return Center(child: Text('No data available', style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
          }
        },
      ),
    );
  }

  String getScoreText(dynamic match) {
    final homeScore = match['score']['fullTime']['home'];
    final awayScore = match['score']['fullTime']['away'];
    return (homeScore != null && awayScore != null) ? '$homeScore - $awayScore' : 'vs';
  }
}

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class CustomSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ThemeData(
      fontFamily: 'Lexend',
      appBarTheme: AppBarTheme(backgroundColor: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDarkMode ? const Color.fromARGB(170, 240, 240, 240) : Colors.black54),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffe6ac), width: 3.0)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffe6ac), width: 1.7)),
      ),
      textTheme: TextTheme(titleLarge: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return [
      IconButton(
        icon: Icon(Icons.clear, color: isDarkMode ? Colors.white : Colors.black),
        onPressed: () { query = ''; },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
      onPressed: () { close(context, null); },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode ? [const Color(0xFF1D1D1D), const Color(0xFF292929)] : [Colors.white, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(child: Text(query, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black))),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final suggestions = query.isEmpty ? [] : ['Suggestion 1', 'Suggestion 2', 'Suggestion 3'];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode ? [const Color(0xFF1D1D1D), const Color(0xFF292929)] : [Colors.white, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(suggestions[index], style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
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