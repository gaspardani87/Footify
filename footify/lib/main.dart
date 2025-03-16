//main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:provider/provider.dart';
import 'package:footify/calendar.dart';
import 'package:footify/leagues.dart';
import 'package:footify/profile.dart';
import 'package:footify/settings.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data' show Uint8List;
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
import 'package:footify/match_details.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'loading_screen.dart';
import 'animated_splash_screen.dart';

// A simple in-memory image cache
class ImageCache {
  static final Map<String, Uint8List> _cache = {};
  
  static Uint8List? getImage(String url) {
    return _cache[url];
  }
  
  static void cacheImage(String url, Uint8List bytes) {
    _cache[url] = bytes;
  }
  
  static bool hasImage(String url) {
    return _cache.containsKey(url);
  }
}

late Future<Map<String, dynamic>> Function() fetchData;
bool isDataPreloaded = false;
Map<String, dynamic>? preloadedData;

Future<Map<String, dynamic>> fetchDataFirebase() async {
  const String url = 'https://us-central1-footify-13da4.cloudfunctions.net/fetchFootballData';
  
  // First, check if we have preloaded data
  if (isDataPreloaded && preloadedData != null) {
    return preloadedData!;
  }
  
  try {
    // Add a longer timeout for initial load
    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 20)); // Increased timeout for more stability
    
    print('Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      
      // Validate that the data contains matches
      if (jsonData['matches'] == null) {
        throw Exception('Invalid data format: missing matches');
      }
      
      // Count total matches to ensure all are loaded
      int totalMatches = (jsonData['matches'] as List).length;
      print('Loaded $totalMatches matches');
      
      // Cache the data for future use
      preloadedData = jsonData;
      isDataPreloaded = true;
      
      return jsonData;
    } else {
      throw Exception('Failed: ${response.statusCode} - ${response.body}');
    }
  } on http.ClientException catch (e) {
    print('ClientException: ${e.message}, URI: ${e.uri}');
    throw Exception('ClientException: Failed to fetch data - ${e.message}');
  } on TimeoutException catch (_) {
    print('Timeout: Request took too long to complete');
    throw Exception('Connection timeout. Please check your internet connection and try again.');
  } catch (e) {
    print('Error: $e');
    throw Exception('Error: $e');
  }
}

// Add a function to preload data in background
Future<void> preloadData() async {
  try {
    preloadedData = await fetchDataFirebase();
    isDataPreloaded = true;
  } catch (e) {
    print('Preload error: $e');
    isDataPreloaded = false;
  }
}

Future<void> initializeApp() async {
  // Initialize Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  fetchData = fetchDataFirebase;
  
  // We're not using native splash screen anymore
  // Just initialize and let the custom loading screen handle everything
}

void main() async {
  await initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontSizeProvider()),
        ChangeNotifierProvider(create: (_) => ColorBlindModeProvider()),
        ChangeNotifierProvider(create: (_) => FirebaseProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const FootifyApp(),
    ),
  );
}

class FootifyApp extends StatefulWidget {
  const FootifyApp({super.key});

  @override
  _FootifyAppState createState() => _FootifyAppState();
}

class _FootifyAppState extends State<FootifyApp> {
  @override
  void initState() {
    super.initState();
    // Start data loading in the background
    preloadData().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

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
      home: const AnimatedSplashScreen(),
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
  late Future<Map<String, dynamic>> _futureData;
  Map<String, bool> _expandedCompetitions = {};
  Map<String, bool> _expandedMatches = {};
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_blinkController);
    
    // Always use preloaded data - the loading screen should have handled this
    _futureData = Future.value(preloadedData ?? {});
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  // Home button handling - no loading indicator needed
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    Widget page;
    switch (index) {
      case 0:
        page = const MainScreen();
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
        page = const FootifyApp();
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

  // Update getProxiedImageUrl to manage the caching mechanism
  String getProxiedImageUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) return '';
    if (kIsWeb) {
      // Proxy through Firebase function for web
      return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
    }
    // Use direct URL for mobile
    return originalUrl;
  }

  // Add a new method to load and cache images
  Future<Uint8List?> getImageBytes(String url) async {
    // Check cache first
    if (ImageCache.hasImage(url)) {
      return ImageCache.getImage(url);
    }
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        // Cache image for future use
        ImageCache.cacheImage(url, bytes);
        return bytes;
      }
    } catch (e) {
      print('Failed to load image: $e');
    }
    return null;
  }

  // Replace the existing team logo image widget with an optimized version that uses caching
  Widget buildTeamLogoImage(String? logoUrl, ColorScheme colorScheme) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(4)
        ),
        child: Icon(Icons.sports_soccer, size: 16, color: colorScheme.onSurface),
      );
    }
    
    final proxyUrl = getProxiedImageUrl(logoUrl);
    
    // Use CachedNetworkImage for better caching and performance
    return CachedNetworkImage(
      imageUrl: proxyUrl,
      width: 24,
      height: 24,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(4)
        ),
        child: const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(4)
        ),
        child: Icon(Icons.sports_soccer, size: 16, color: colorScheme.onSurface),
      ),
      memCacheWidth: 48, // For high-res displays
      memCacheHeight: 48,
      cacheKey: proxyUrl, // Use the URL as cache key
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
          // Handle error case
          if (snapshot.hasError || _hasError) {
            return _buildErrorWidget(isDarkMode, colorScheme);
          }
          
          // Show data immediately
          if (snapshot.hasData && snapshot.data!['matches'] != null) {
            return _buildMatchesList(snapshot.data!, isDarkMode, colorScheme);
          }
          
          // Fallback for empty data (should rarely happen)
          return Center(
            child: Text(
              'No matches available', 
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)
            )
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(bool isDarkMode, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 64,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage.contains('No matches available') 
                  ? 'No matches available at the moment. Please try again later.'
                  : 'Please check your internet connection!',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 18,
                fontFamily: 'Lexend',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_errorMessage.isNotEmpty && !_errorMessage.contains('No matches available'))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontSize: 14,
                    fontFamily: 'Lexend',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Properly reload data when retry is pressed
                setState(() {
                  _hasError = false;
                });
                
                // Try to load fresh data
                preloadData().then((_) {
                  if (mounted) {
                    setState(() {
                      _futureData = Future.value(preloadedData ?? {});
                    });
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Retry', style: TextStyle(fontFamily: 'Lexend')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchesList(Map<String, dynamic> data, bool isDarkMode, ColorScheme colorScheme) {
    // Process the data in chunks to avoid UI jank
    if (data.containsKey('_processedMatches')) {
      // Data is already processed, use the cached result
      Map<String, List<dynamic>> matchesByCompetition = data['_processedMatches'];
      List<String> sortedCompetitions = data['_sortedCompetitions'];
      
      return _buildMatchesListUI(matchesByCompetition, sortedCompetitions, isDarkMode, colorScheme);
    } else {
      // Data needs processing - do it once and cache the result
      return FutureBuilder<Map<String, dynamic>>(
        future: _processMatchesData(data),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingIndicator(isDarkMode, colorScheme);
          } else if (snapshot.hasError) {
            return Center(child: Text('Error processing data: ${snapshot.error}', 
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
          } else if (snapshot.hasData) {
            final processedData = snapshot.data!;
            Map<String, List<dynamic>> matchesByCompetition = processedData['_processedMatches'];
            List<String> sortedCompetitions = processedData['_sortedCompetitions'];
            
            return _buildMatchesListUI(matchesByCompetition, sortedCompetitions, isDarkMode, colorScheme);
          } else {
            return Center(child: Text('No match data available', 
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
          }
        },
      );
    }
  }
  
  // Process matches data in an isolate to avoid UI freezes
  Future<Map<String, dynamic>> _processMatchesData(Map<String, dynamic> data) async {
    // Create a copy of the data to avoid modifying the original
    final result = Map<String, dynamic>.from(data);
    
    // Group matches by competition
    final Map<String, List<dynamic>> matchesByCompetition = {};
    for (var match in data['matches']) {
      final competitionName = match['competition']['name'] ?? 'Other Competitions';
      if (!matchesByCompetition.containsKey(competitionName)) {
        matchesByCompetition[competitionName] = [];
      }
      matchesByCompetition[competitionName]!.add(match);
    }
    
    // Sort competitions by name
    final sortedCompetitions = matchesByCompetition.keys.toList()..sort();
    
    // Store processed data
    result['_processedMatches'] = matchesByCompetition;
    result['_sortedCompetitions'] = sortedCompetitions;
    result['_processedTimestamp'] = DateTime.now().millisecondsSinceEpoch;
    
    // Cache the processed data
    if (preloadedData != null) {
      preloadedData!['_processedMatches'] = matchesByCompetition;
      preloadedData!['_sortedCompetitions'] = sortedCompetitions;
      preloadedData!['_processedTimestamp'] = result['_processedTimestamp'];
    }
    
    return result;
  }
  
  // Build the actual list UI with processed data
  Widget _buildMatchesListUI(Map<String, List<dynamic>> matchesByCompetition, List<String> sortedCompetitions, bool isDarkMode, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCompetitions.length,
      itemBuilder: (context, index) {
        final competitionName = sortedCompetitions[index];
        final matches = matchesByCompetition[competitionName]!;
        
        // Kinyerjük a bajnokság emblémáját és ID-jét az első mérkőzés adataiból
        final competitionEmblem = matches.isNotEmpty ? matches[0]['competition']['emblem'] : null;
        final competitionId = matches.isNotEmpty ? matches[0]['competition']['id'] : null;
        
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
                          // Használjuk ugyanazt a logó mechanizmust, mint a leagues.dart-ban
                          _buildLeagueLogo(competitionId, competitionEmblem, isDarkMode, colorScheme),
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
                  // Use AnimatedSize for smoother transitions
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _expandedCompetitions[competitionName] ?? true
                        ? _buildMatchesListView(matches, isDarkMode, colorScheme)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Build the list of matches for a competition
  Widget _buildMatchesListView(List<dynamic> matches, bool isDarkMode, ColorScheme colorScheme) {
    return ListView.separated(
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
        
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MatchDetailsPage(matchData: match),
              ),
            );
          },
          child: Padding(
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
                            child: buildTeamLogoImage(match['homeTeam']['crest'], colorScheme),
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
                            child: buildTeamLogoImage(match['awayTeam']['crest'], colorScheme),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String getScoreText(dynamic match) {
    final homeScore = match['score']['fullTime']['home'];
    final awayScore = match['score']['fullTime']['away'];
    return (homeScore != null && awayScore != null) ? '$homeScore - $awayScore' : 'vs';
  }

  // Add the simplified loading indicator method
  Widget _buildLoadingIndicator(bool isDarkMode, ColorScheme colorScheme) {
    return Center(
      child: CircularProgressIndicator(
        color: colorScheme.primary,
      ),
    );
  }

  // Új metódus a bajnokság logók megjelenítéséhez, a leagues.dart-hoz hasonlóan
  Widget _buildLeagueLogo(int? competitionId, String? logoUrl, bool isDarkMode, ColorScheme colorScheme) {
    // Ha nincs competitionId, akkor alapértelmezett ikont jelenítünk meg
    if (competitionId == null) {
      return Icon(Icons.emoji_events, color: isDarkMode ? Colors.black : Colors.black, size: 24);
    }
    
    // Jobb minőségű helyettesítő logók a bajnokságokhoz - ugyanaz mint a leagues.dart-ban
    Map<int, String> replacementLogos = {
      2013: 'https://upload.wikimedia.org/wikipedia/en/0/04/Campeonato_Brasileiro_S%C3%A9rie_A.png', // Brasileiro Série A
      2018: 'https://static.wikia.nocookie.net/future/images/8/84/Euro_2028_Logo_Concept_v2.png/revision/latest?cb=20231020120018', // European Championship
      2003: 'https://upload.wikimedia.org/wikipedia/commons/4/46/Eredivisie_nuovo_logo.png', // Eredivisie
      2000: 'https://upload.wikimedia.org/wikipedia/en/thumb/1/17/2026_FIFA_World_Cup_emblem.svg/1200px-2026_FIFA_World_Cup_emblem.svg.png', // FIFA World Cup
      2015: 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Ligue1_Uber_Eats_logo.png/1200px-Ligue1_Uber_Eats_logo.png', // Ligue 1 (nagyobb felbontás)
      2019: 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e9/Serie_A_logo_2022.svg/1200px-Serie_A_logo_2022.svg.png', // Serie A
      2014: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0f/LaLiga_logo_2023.svg/2560px-LaLiga_logo_2023.svg.png', // LaLiga
      2021: 'https://www.sportmonks.com/wp-content/uploads/2024/08/Premier_League_Logo-1.png', // Premier League 
      2152: 'https://upload.wikimedia.org/wikipedia/en/thumb/a/a1/Copa_Libertadores_logo.svg/1200px-Copa_Libertadores_logo.svg.png', // Copa Libertadores
      2001: 'https://assets-us-01.kc-usercontent.com/31dbcbc6-da4c-0033-328a-d7621d0fa726/8e5c2681-8c90-4c64-a79d-2a4fa17834c7/UEFA_Champions_League_Logo.png', // Champions League
      2002: 'https://upload.wikimedia.org/wikipedia/en/thumb/d/df/Bundesliga_logo_%282017%29.svg/1200px-Bundesliga_logo_%282017%29.svg.png', // Bundesliga
      2017: 'https://news.22bet.com/wp-content/uploads/2023/11/liga-portugal-logo-white.png', // Primeira Liga
    };
    
    // Sötét témájú verziók a világos módban nem jól látható logókhoz
    Map<int, String> darkVersionLogos = {
      2021: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Premier_League_Logo.svg/1200px-Premier_League_Logo.svg.png', // Premier League (sötét verzió)
      2001: 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f5/UEFA_Champions_League.svg/1200px-UEFA_Champions_League.svg.png', // Champions League (sötét verzió)
      2017: 'https://cdn.freelogovectors.net/wp-content/uploads/2021/08/primeira-logo-liga-portugal-freelogovectors.net_.png', // Primeira Liga (sötét verzió)
    };
    
    // Proxy használata a webes verzióban
    String getProxiedUrl(String url) {
      if (kIsWeb) {
        // Ha SVG formátumú a kép, közvetlenül használjuk
        if (url.toLowerCase().endsWith('.svg') || url.toLowerCase().contains('.svg')) {
          return url;
        }
        return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(url)}';
      }
      return url;
    }
    
    // A problémás ligák világos módban sötét verziójú képet használnak
    if (!isDarkMode && darkVersionLogos.containsKey(competitionId)) {
      return Container(
        width: 24,
        height: 24,
        child: Image.network(
          getProxiedUrl(darkVersionLogos[competitionId]!),
          fit: BoxFit.contain,
          headers: kIsWeb ? {'Origin': 'null'} : null,
          errorBuilder: (context, error, stackTrace) {
            print("Sötét verzió betöltési hiba (ID: $competitionId): $error");
            return Icon(Icons.emoji_events, color: Colors.black, size: 24);
          },
        ),
      );
    }
    
    // Speciális kezelés a sárgás háttéren látható logók számára sötét módban
    if (isDarkMode && (competitionId == 2021 || competitionId == 2017 || competitionId == 2003)) {
      // Premier League, Primeira Liga és Eredivisie esetén fekete logókat használunk a sárgás háttéren
      String specialLogoUrl = competitionId == 2021 
          ? 'https://upload.wikimedia.org/wikipedia/en/thumb/f/f2/Premier_League_Logo.svg/1200px-Premier_League_Logo.svg.png'  // Premier League fekete logó
          : competitionId == 2017 
              ? 'https://cdn.freelogovectors.net/wp-content/uploads/2021/08/primeira-logo-liga-portugal-freelogovectors.net_.png'  // Primeira Liga fekete logó
              : 'https://upload.wikimedia.org/wikipedia/commons/4/46/Eredivisie_nuovo_logo.png';  // Eredivisie eredeti logó
      
      return Container(
        width: 24,
        height: 24,
        child: Image.network(
          getProxiedUrl(specialLogoUrl),
          fit: BoxFit.contain,
          headers: kIsWeb ? {'Origin': 'null'} : null,
          errorBuilder: (context, error, stackTrace) {
            print("Speciális verzió betöltési hiba (ID: $competitionId): $error");
            return Icon(
              Icons.emoji_events, 
              color: Colors.black, 
              size: 24
            );
          },
        ),
      );
    }
    
    // Champions League esetén fekete szín sötét módban, a sárgás háttéren
    if (competitionId == 2001 && isDarkMode) {
      return Container(
        width: 24,
        height: 24,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.black,
            BlendMode.srcIn,
          ),
          child: Image.network(
            getProxiedUrl(logoUrl ?? replacementLogos[competitionId]!),
            fit: BoxFit.contain,
            headers: kIsWeb ? {'Origin': 'null'} : null,
            errorBuilder: (context, error, stackTrace) {
              print("Fekete színezésű logó betöltési hiba (ID: $competitionId): $error");
              return Icon(
                Icons.emoji_events, 
                color: Colors.black, 
                size: 24
              );
            },
          ),
        ),
      );
    }
    
    // Ellenőrizzük, hogy van-e helyettesítő online kép
    if (replacementLogos.containsKey(competitionId)) {
      return Container(
        width: 24,
        height: 24,
        child: Image.network(
          getProxiedUrl(replacementLogos[competitionId]!),
          fit: BoxFit.contain,
          headers: kIsWeb ? {'Origin': 'null'} : null,
          errorBuilder: (context, error, stackTrace) {
            print("Helyettesítő kép betöltési hiba (ID: $competitionId): $error");
            return Icon(
              Icons.emoji_events, 
              color: isDarkMode ? Colors.black : Colors.black, 
              size: 24
            );
          },
        ),
      );
    }
    
    // Minden más esetben az eredeti logót használjuk
    return Container(
      width: 24,
      height: 24,
      child: _getNetworkImageForLeague(logoUrl, isDarkMode),
    );
  }
  
  // Segédfüggvény a hálózati kép megjelenítéséhez
  Widget _getNetworkImageForLeague(String? logoUrl, bool isDarkMode) {
    if (logoUrl == null || logoUrl.isEmpty) {
      return Icon(Icons.emoji_events, color: Colors.black, size: 24);
    }
    
    // Proxy használata a webes verzióban
    String proxyUrl = logoUrl;
    if (kIsWeb) {
      // Ha SVG formátumú a kép, közvetlenül használjuk
      if (logoUrl.toLowerCase().endsWith('.svg') || logoUrl.toLowerCase().contains('.svg')) {
        proxyUrl = logoUrl;
      } else {
        proxyUrl = 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(logoUrl)}';
      }
    }
    
    return Image.network(
      proxyUrl,
      fit: BoxFit.contain,
      width: 24,
      height: 24,
      headers: kIsWeb ? {'Origin': 'null'} : null,
      errorBuilder: (context, error, stackTrace) {
        print("Logó betöltési hiba: $error (URL: $logoUrl)");
        return Icon(Icons.emoji_events, color: Colors.black, size: 24);
      },
    );
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

// A clean loading screen with just a pulsating SVG logo
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({Key? key}) : super(key: key);

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Create a subtle pulsating animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    
    // Subtle pulsating effect (0.85 to 1.1)
    _animation = Tween<double>(begin: 0.85, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Start loading data in background
    _startDataLoading();
  }

  void _startDataLoading() async {
    if (!isDataPreloaded) {
      try {
        await preloadData();
        if (mounted && isDataPreloaded) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } catch (e) {
        print('Loading error: $e');
        // Keep showing loading screen, retry loading in background
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            _startDataLoading();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Determine logo path based on theme
    final String logoPath = isDarkMode 
        ? 'assets/images/footify_logo_optimized_dark.svg'
        : 'assets/images/footify_logo_optimized_light.svg';
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: ScaleTransition(
          scale: _animation,
          child: SvgPicture.asset(
            logoPath,
            width: 250,
            height: 150,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}