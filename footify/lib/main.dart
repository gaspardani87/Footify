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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'services/football_api_service.dart' as football_api;
import 'dashboard.dart';
import 'popup_demo.dart';
import 'package:footify/team_details.dart';
import 'dart:async'; // Import Timer
import 'package:intl/intl.dart';

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

  // Initialize FootballApiService with your Firebase project ID
  football_api.FootballApiService.initialize('footify-13da4');

  fetchData = fetchDataFirebase;
  
  // We're not using native splash screen anymore
  // Just initialize and let the custom loading screen handle everything
}

// Globális navigatorKey, amit bárhol elérhetünk az alkalmazásban
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
      // Adjuk meg a navigatorKey-t a MaterialApp-nak
      navigatorKey: navigatorKey,
      theme: _buildTheme(ThemeData.light(), fontSizeProvider.fontSize, Provider.of<ColorBlindModeProvider>(context).isColorBlindMode),
      darkTheme: _buildTheme(ThemeData.dark(), fontSizeProvider.fontSize, Provider.of<ColorBlindModeProvider>(context).isColorBlindMode),
      themeMode: themeProvider.themeMode,
      locale: languageProvider.currentLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AnimatedSplashScreen(),
      // Add builder to ensure the overlay for message popups works
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => child!,
            ),
          ],
        );
      },
    );
  }

  // Helper function to build a theme with dynamic font size and color blind mode
  ThemeData _buildTheme(ThemeData baseTheme, double fontSize, bool isColorBlindMode) {
    var isDarkMode = baseTheme.brightness == Brightness.dark;
    
    final colorBlindPalette = isDarkMode ? {
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

    final regularPalette = isDarkMode ? {
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
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        primary: colors['primary']!,
        onPrimary: colors['text']!,
        secondary: colors['secondary']!,
        onSecondary: colors['text']!,
        error: Colors.red,
        onError: Colors.white,
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
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(
          fontSize: fontSize,
          color: isDarkMode ? Colors.white70 : Colors.black54,
        ),
        hintStyle: TextStyle(
          fontSize: fontSize,
          color: isDarkMode ? Colors.white30 : Colors.black38,
        ),
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
  final Map<String, bool> _expandedCompetitions = {};
  final Map<String, bool> _expandedMatches = {};
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _hasError = false;
  final String _errorMessage = '';
  final int _totalMatchesLoaded = 0;

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
        page = const DashboardPage();
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
    
    // Handle the case where the URL is already a proxy URL
    if (originalUrl.contains('proxyImage?url=')) return originalUrl;
    
    // For web, use proxy for all images to avoid CORS issues
    if (kIsWeb) {
      return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
    }
    
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
          color: colorScheme.surfaceContainerHighest,
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
          color: colorScheme.surfaceContainerHighest,
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
          color: colorScheme.surfaceContainerHighest,
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

    return Scaffold(
      body: Stack(
        children: [
          CommonLayout(
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
          ),
          
          // Button for testing message popups
          Positioned(
            bottom: 90,  // Position it just above the bottom navigation
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PopupDemoPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFE6AC),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.message),
                  const SizedBox(width: 8),
                  Text('Messages'),
                ],
              ),
            ),
          ),
        ],
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
            
            // Check if there are no matches at all in the data
            if (data['matches'] == null || (data['matches'] as List).isEmpty) {
              // Return empty state UI immediately
              return _buildMatchesListUI({}, [], isDarkMode, colorScheme);
            }
            
            return _buildMatchesListUI(matchesByCompetition, sortedCompetitions, isDarkMode, colorScheme);
          } else {
            // When no data is available, pass empty collections
            return _buildMatchesListUI({}, [], isDarkMode, colorScheme);
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
    // Check if there are any matches (competitions)
    if (sortedCompetitions.isEmpty) {
      // Get random message key
      final random = Random();
      final int randomIndex = random.nextInt(30) + 1; // 1-30
      final String titleKey = 'emptyFixtureTitle$randomIndex';
      
      // Get random message subtitle for empty competition
      final subtitleKey = 'emptyFixtureSubtitle$randomIndex';
      
      // Get the default message
      final Map<String, String> defaultMessages = {
        'emptyFixtureTitle': "Empty fixture list? Let's call it strategic silence. 🧠⚽",
        'emptyFixtureTitle1': "Stadium seats are empty… 🏟️",
        'emptyFixtureTitle2': "The whistle hasn't blown… yet! 🎶",
        'emptyFixtureTitle3': "Even superstars need a timeout. 🌟",
        'emptyFixtureTitle4': "The playbook is wide open… 📖",
        'emptyFixtureTitle5': "No live goals? Practice your victory chant! 🎤",
        'emptyFixtureTitle6': "The trophy is polishing itself… 🏆✨",
        'emptyFixtureTitle7': "The transfer window is closed… 🚪🔒",
        'emptyFixtureTitle8': "The grass is growing… quietly. 🌱",
        'emptyFixtureTitle9': "Offside? Nope—just a breather! 🚩",
        'emptyFixtureTitle10': "The corner flags are chilling… 🍹",
        'emptyFixtureTitle11': "The scorekeeper's pencil is sharpened! ✏️",
        'emptyFixtureTitle12': "The VAR room is quiet… for now. 📺",
        'emptyFixtureTitle13': "The halftime oranges are being sliced… 🍊",
        'emptyFixtureTitle14': "The fans are stretching their vocal cords… 📢",
        'emptyFixtureTitle15': "The red card is hiding… 😈",
        'emptyFixtureTitle16': "The golden boot is taking a shine… 👟",
        'emptyFixtureTitle17': "The manager's whiteboard is blank… 🤔",
        'emptyFixtureTitle18': "The penalty spot is practicing its drama… 🎭",
        'emptyFixtureTitle19': "The crossbar is enjoying the peace… ⚽❌",
        'emptyFixtureTitle20': "Your app is in preseason mode… 🏋️♂️",
        'emptyFixtureTitle21': "The pitch is quiet… for now! ⚽",
        'emptyFixtureTitle22': "No matches live? Time to warm up! 🏃♂️",
        'emptyFixtureTitle23': "All calm on the football front. 🌤️",
        'emptyFixtureTitle24': "Halftime for updates! ☕",
        'emptyFixtureTitle25': "No games? No problem! 🧘",
        'emptyFixtureTitle26': "The scoreboard is taking a nap… 😴",
        'emptyFixtureTitle27': "Shhh… the footballs are resting. 🌙",
        'emptyFixtureTitle28': "No matches yet?",
        'emptyFixtureTitle29': "The stadium lights are dimmed… 🌟",
        'emptyFixtureTitle30': "Football's taking a breather... 🧠",
      };
      
      final String title = AppLocalizations.of(context)!.emptyFixtureTitle ??  "Empty fixture list? Let's call it strategic silence. 🧠⚽";
      
      // Get the default subtitle
      final Map<String, String> defaultSubtitles = {
        'emptyFixtureSubtitle1': "But don't worry—the fans (and goals) are on their way!",
        'emptyFixtureSubtitle2': "Use this time to perfect your goal celebration pose.",
        'emptyFixtureSubtitle3': "Grab a Gatorade—we'll shout when the magic returns!",
        'emptyFixtureSubtitle4': "Study up! Your next prediction could be legendary.",
        'emptyFixtureSubtitle5': "(We recommend 'Olé, Olé, Olé!' for maximum vibes.)",
        'emptyFixtureSubtitle6': "It'll shine even brighter for the next champion!",
        'emptyFixtureSubtitle7': "But drama always finds its way back. Stay tuned!",
        'emptyFixtureSubtitle8': "Perfect conditions for future hat-trick heroes!",
        'emptyFixtureSubtitle9': "Refuel and return for the next heart-stopping match.",
        'emptyFixtureSubtitle10': "They'll be dancing in the wind again soon!",
        'emptyFixtureSubtitle11': "Ready to document the next epic comeback.",
        'emptyFixtureSubtitle12': "Controversy-free zone (temporarily). Enjoy the peace!",
        'emptyFixtureSubtitle13': "Fresh energy incoming! ⚡",
        'emptyFixtureSubtitle14': "\"GOOOOOOAL!\" practice sessions in progress.",
        'emptyFixtureSubtitle15': "Let's hope it stays in the ref's pocket next game!",
        'emptyFixtureSubtitle16': "Your favorite striker might claim it soon!",
        'emptyFixtureSubtitle17': "Genius tactics are brewing… we can feel it.",
        'emptyFixtureSubtitle18': "Cue suspenseful music…",
        'emptyFixtureSubtitle19': "(For now, no heartbreaking near-misses.)",
        'emptyFixtureSubtitle20': "Training hard to deliver top-tier updates!",
        'emptyFixtureSubtitle21': "Check back soon—goals are just around the corner!",
        'emptyFixtureSubtitle22': "Grab a snack and stay tuned—action is coming.",
        'emptyFixtureSubtitle23': "Perfect time to predict your next win!",
        'emptyFixtureSubtitle24': "Relax, recharge, and return for the next kickoff.",
        'emptyFixtureSubtitle25': "Use this break to plan your victory dance.",
        'emptyFixtureSubtitle26': "Wake it up later with live matches!",
        'emptyFixtureSubtitle27': "They'll be back soon, louder than ever!",
        'emptyFixtureSubtitle28': "Pro Tip: Pretend you're the referee—everyone will listen. 😉",
        'emptyFixtureSubtitle29': "But don't worry—the next showdown is being prepped!",
        'emptyFixtureSubtitle30': "Like all great stories, there's a pause before the action!",
      };
      
      final String subtitle =  AppLocalizations.of(context)!.emptyFixtureSubtitle ?? "Greatness awaits—we'll notify you when it's game time!";
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_soccer,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Lexend',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 16,
                  fontFamily: 'Lexend',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Continue with existing code for the case when matches exist
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
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              elevation: 3,
              color: isDarkMode ? const Color(0xFF292929) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
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
    // Check if the competition has any matches
    if (matches.isEmpty) {
      // Get random message subtitle for empty competition
      final random = Random();
      final int randomIndex = random.nextInt(30) + 1; // 1-30
      final String subtitleKey = 'emptyFixtureSubtitle$randomIndex';
      
      // Get the default message
      final Map<String, String> defaultSubtitles = {
        'emptyFixtureSubtitle1': "But don't worry—the fans (and goals) are on their way!",
        'emptyFixtureSubtitle2': "Use this time to perfect your goal celebration pose.",
        'emptyFixtureSubtitle3': "Grab a Gatorade—we'll shout when the magic returns!",
        'emptyFixtureSubtitle4': "Study up! Your next prediction could be legendary.",
        'emptyFixtureSubtitle5': "(We recommend 'Olé, Olé, Olé!' for maximum vibes.)",
        'emptyFixtureSubtitle6': "It'll shine even brighter for the next champion!",
        'emptyFixtureSubtitle7': "But drama always finds its way back. Stay tuned!",
        'emptyFixtureSubtitle8': "Perfect conditions for future hat-trick heroes!",
        'emptyFixtureSubtitle9': "Refuel and return for the next heart-stopping match.",
        'emptyFixtureSubtitle10': "They'll be dancing in the wind again soon!",
        'emptyFixtureSubtitle11': "Ready to document the next epic comeback.",
        'emptyFixtureSubtitle12': "Controversy-free zone (temporarily). Enjoy the peace!",
        'emptyFixtureSubtitle13': "Fresh energy incoming! ⚡",
        'emptyFixtureSubtitle14': "\"GOOOOOOAL!\" practice sessions in progress.",
        'emptyFixtureSubtitle15': "Let's hope it stays in the ref's pocket next game!",
        'emptyFixtureSubtitle16': "Your favorite striker might claim it soon!",
        'emptyFixtureSubtitle17': "Genius tactics are brewing… we can feel it.",
        'emptyFixtureSubtitle18': "Cue suspenseful music…",
        'emptyFixtureSubtitle19': "(For now, no heartbreaking near-misses.)",
        'emptyFixtureSubtitle20': "Training hard to deliver top-tier updates!",
        'emptyFixtureSubtitle21': "Check back soon—goals are just around the corner!",
        'emptyFixtureSubtitle22': "Grab a snack and stay tuned—action is coming.",
        'emptyFixtureSubtitle23': "Perfect time to predict your next win!",
        'emptyFixtureSubtitle24': "Relax, recharge, and return for the next kickoff.",
        'emptyFixtureSubtitle25': "Use this break to plan your victory dance.",
        'emptyFixtureSubtitle26': "Wake it up later with live matches!",
        'emptyFixtureSubtitle27': "They'll be back soon, louder than ever!",
        'emptyFixtureSubtitle28': "Pro Tip: Pretend you're the referee—everyone will listen. 😉",
        'emptyFixtureSubtitle29': "But don't worry—the next showdown is being prepped!",
        'emptyFixtureSubtitle30': "Like all great stories, there's a pause before the action!",
      };
      
      final String subtitle = defaultSubtitles[subtitleKey] ?? "Greatness awaits—we'll notify you when it's game time!";
      
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 32,
              color: colorScheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
                fontFamily: 'Lexend',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // The rest of the existing code - make sure this block ALWAYS returns a Widget
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
                builder: (context) => MatchDetailsPage(matchData: {
                  'id': match['id'],
                  'homeTeam': {'name': match['homeTeam'], 'id': match['homeTeamId']},
                  'awayTeam': {'name': match['awayTeam'], 'id': match['awayTeamId']},
                  'status': match['status'],
                  'score': match['score'],
                  'competition': {
                    'name': match['competition'],
                    'id': match['competitionId'],
                    'emblem': match['competitionEmblem'],
                  },
                  'utcDate': match['date'],
                }),
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
                        color: matchStatus == 'FINISHED' ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
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
      return SizedBox(
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
      
      return SizedBox(
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
      return SizedBox(
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
      return SizedBox(
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
    return SizedBox(
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
  Timer? _debounce;
  // Add a static cache for search results
  static final Map<String, List<Map<String, dynamic>>> _searchCache = {};
  // Store the last query to preserve search state
  static String _lastQuery = '';
  // Store search history - switching from strings to objects
  static List<Map<String, dynamic>> _searchHistoryItems = [];
  // Maximum number of history items to keep
  static const int _maxHistoryItems = 15;
  // Flag to check if history is initialized
  static bool _isHistoryInitialized = false;
  
  // Override query setter to update our internal state
  @override
  set query(String value) {
    super.query = value;
  }
  
  // Initialize with the last query when opened
  CustomSearchDelegate() {
    if (_lastQuery.isNotEmpty) {
      super.query = _lastQuery;
    }
    
    // Initialize history from storage if not done already
    if (!_isHistoryInitialized) {
      _initializeHistory();
    }
  }
  
  // Initialize search history from SharedPreferences
  Future<void> _initializeHistory() async {
    _isHistoryInitialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('search_history');
      
      if (historyJson != null && historyJson.isNotEmpty) {
        // Convert from JSON
        final List<dynamic> decoded = jsonDecode(historyJson);
        _searchHistoryItems = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        print("[CustomSearchDelegate] Loaded ${_searchHistoryItems.length} history items from storage");
      }
    } catch (e) {
      print("[CustomSearchDelegate] Error loading search history: $e");
    }
  }
  
  // Save search history to SharedPreferences
  static Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = jsonEncode(_searchHistoryItems);
      await prefs.setString('search_history', historyJson);
      print("[CustomSearchDelegate] Saved ${_searchHistoryItems.length} history items to storage");
    } catch (e) {
      print("[CustomSearchDelegate] Error saving search history: $e");
    }
  }

  // Add a team or league to search history
  static void addToHistory(Map<String, dynamic> item) {
    if (item.isEmpty) return;
    
    // Make sure we have all required fields
    final String type = item['type'] as String? ?? '';
    if (type != 'team' && type != 'competition' && type != 'match') {
      return; // Only save teams, competitions/leagues and matches
    }
    
    // Create a simplified version to store in history
    final Map<String, dynamic> historyItem;
    
    if (type == 'match') {
      // Process match data - handle the structure properly
      // The method is called from two places: _navigateToHistoryItem and onTap, with different data structures
      // So we need to handle both cases
      
      final String homeTeamName = item['homeTeam'] is Map ? 
        item['homeTeam']['name'] : 
        item['homeTeam'];
        
      final String awayTeamName = item['awayTeam'] is Map ? 
        item['awayTeam']['name'] : 
        item['awayTeam'];
        
      final homeTeamId = item['homeTeam'] is Map ? 
        item['homeTeam']['id'] : 
        item['homeTeamId'];
        
      final awayTeamId = item['awayTeam'] is Map ? 
        item['awayTeam']['id'] : 
        item['awayTeamId'];
        
      final homeTeamEmblem = item['homeTeam'] is Map ? 
        item['homeTeam']['emblem'] ?? item['homeTeam']['crest'] : 
        item['homeTeamLogo'];
        
      final awayTeamEmblem = item['awayTeam'] is Map ? 
        item['awayTeam']['emblem'] ?? item['awayTeam']['crest'] : 
        item['awayTeamLogo'];
        
      final competitionName = item['competition'] is Map ? 
        item['competition']['name'] : 
        item['competition'];
        
      historyItem = {
        'id': item['id'],
        'type': 'match',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'homeTeam': homeTeamName,
        'awayTeam': awayTeamName,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'homeTeamLogo': homeTeamEmblem ?? '',
        'awayTeamLogo': awayTeamEmblem ?? '',
        'homeTeamShortName': item['homeTeamShortName'] ?? homeTeamName,
        'awayTeamShortName': item['awayTeamShortName'] ?? awayTeamName,
        'competition': competitionName ?? 'Unknown Competition',
        'competitionId': item['competition'] is Map ? item['competition']['id'] : item['competitionId'],
        'competitionEmblem': item['competition'] is Map ? item['competition']['emblem'] : item['competitionEmblem'],
        'status': item['status'] ?? 'SCHEDULED',
        'date': item['utcDate'] ?? item['date'],
        'score': item['score'],
      };
    } else {
      // Process team or competition data
      historyItem = {
      'id': item['id'],
      'name': item['name'],
      'emblem': item['emblem'],
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    }
    
    // Remove if exists (to reorder)
    _searchHistoryItems.removeWhere((existing) => 
      existing['id'] == historyItem['id'] && existing['type'] == historyItem['type']
    );
    
    // Add to beginning of list
    _searchHistoryItems.insert(0, historyItem);
    
    // Limit size
    if (_searchHistoryItems.length > _maxHistoryItems) {
      _searchHistoryItems.removeLast();
    }
    
    // Save to persistent storage
    _saveHistory();
  }
  
  // Clear search history
  static Future<void> clearHistory() async {
    _searchHistoryItems.clear();
    await _saveHistory();
  }

  @override
  void close(BuildContext context, result) {
    // Remember the query before closing
    _lastQuery = super.query;
    super.close(context, result);
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return ThemeData(
      fontFamily: 'Lexend',
      scaffoldBackgroundColor: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontFamily: 'Lexend',
          fontSize: 18,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDarkMode ? const Color.fromARGB(170, 240, 240, 240) : Colors.black54),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffe6ac), width: 3.0)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFffe6ac), width: 1.7)),
        labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontFamily: 'Lexend',
        ),
        bodyLarge: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontFamily: 'Lexend',
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: MaterialStateProperty.all(
          isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
        ),
        textStyle: MaterialStateProperty.all(
          TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontFamily: 'Lexend',
          ),
        ),
        hintStyle: MaterialStateProperty.all(
          TextStyle(
            color: isDarkMode ? const Color.fromARGB(170, 240, 240, 240) : Colors.black54,
            fontFamily: 'Lexend',
          ),
        ),
      ),
    );
  }

  @override
  void showResults(BuildContext context) {
    // Save the current query before showing results
    _lastQuery = super.query;
    // Add to search history - we'll now use addToHistory for items, not queries
    super.showResults(context);
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return [
      IconButton(
        icon: Icon(Icons.clear, color: isDarkMode ? Colors.white : Colors.black),
        onPressed: () { 
          query = ''; 
          _lastQuery = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
      onPressed: () { 
        // Remember the query before closing
        _lastQuery = super.query;
        close(context, null); 
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Cancel any existing debounce timer when showing results
    _debounce?.cancel();
    
    // Check if query is too short
    if (super.query.length < 3) {
      return _buildMinimumCharactersMessage(context, isDarkMode, colorScheme);
    }
    
    return Container(
      color: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        // Use the current query directly
        future: _getSearchResults(super.query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              ),
            );
          }

          final results = snapshot.data ?? [];
          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found for "${super.query}"',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final item = results[index];
              return _buildSearchResultItem(context, item, isDarkMode, colorScheme);
            },
          );
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Debounce logic - only apply when query changes
    if (super.query != _lastQuery) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
        // Remember query for state preservation
        _lastQuery = super.query;
    });
    }

    return Container(
      color: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
      child: super.query.isEmpty
          ? _buildInitialSearchScreen(context, isDarkMode, colorScheme)
          : super.query.length < 3
              ? _buildMinimumCharactersMessage(context, isDarkMode, colorScheme)
          : FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getSearchResults(super.query),
              builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                   return Center(
                      child: CircularProgressIndicator(
                          color: colorScheme.primary,
                      ),
                    );
                  }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                    ),
                  );
                }

                final suggestions = snapshot.data ?? [];
                    if (suggestions.isEmpty && super.query.isNotEmpty) {
                    return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: colorScheme.primary.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No suggestions found for "${super.query}"',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                      ),
                    );
                  }
                  
                return ListView.builder(
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final item = suggestions[index];
                        return _buildSearchResultItem(context, item, isDarkMode, colorScheme);
                      },
                    );
                  },
                ),
    );
  }

  // Helper method to show initial search screen
  Widget _buildInitialSearchScreen(BuildContext context, bool isDarkMode, ColorScheme colorScheme) {
    // Show search history if we have any
    if (_searchHistoryItems.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: const Color(0xFFFFE6AC), // Use the app's yellow accent color
                ),
                const SizedBox(width: 8),
                Text(
                  'Recently Viewed',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Lexend',
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    await clearHistory();
                    // Force rebuild
                    query = '';
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF292929) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                            fontFamily: 'Lexend',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Build the history grid with improved UI
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchHistoryItems.length,
                itemBuilder: (context, index) {
                  final historyItem = _searchHistoryItems[index];
                final String type = historyItem['type'];
                
                // If it's a match, use a match card design
                if (type == 'match') {
                  // Get status and date from history item
                  final matchStatus = historyItem['status'] ?? 'SCHEDULED';
                  DateTime matchDate;
                  try {
                    matchDate = DateTime.parse(historyItem['date'] ?? '');
                  } catch (e) {
                    matchDate = DateTime.now().add(const Duration(days: 1));
                  }
                  
                  // Format date
                  final formattedDate = DateFormat('MMM d, yyyy').format(matchDate);
                  final formattedTime = DateFormat('HH:mm').format(matchDate);
                  
                  // Get score information
                  var homeScore, awayScore;
                  if (historyItem.containsKey('score') && historyItem['score'] != null) {
                    if (historyItem['score'].containsKey('fullTime') && historyItem['score']['fullTime'] != null) {
                      homeScore = historyItem['score']['fullTime']['home'];
                      awayScore = historyItem['score']['fullTime']['away'];
                    }
                  }
                  
                  final hasScore = homeScore != null && awayScore != null;
                  final scoreText = hasScore ? '$homeScore - $awayScore' : 'vs';
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 3,
                    color: isDarkMode ? const Color(0xFF292929) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.2),
                        width: 0.5,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _navigateToHistoryItem(context, historyItem),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header with competition info
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE6AC).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'MATCH',
                                    style: const TextStyle(
                                      color: Color(0xFFFFE6AC),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(matchStatus, isDarkMode),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getStatusText(matchStatus),
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.black : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Lexend',
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (historyItem['competitionEmblem'] != null && historyItem['competitionEmblem'].isNotEmpty)
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          football_api.FootballApiService.getProxyImageUrl(historyItem['competitionEmblem']),
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            print('Error loading competition emblem: $error');
                                            return const Icon(Icons.emoji_events, size: 24);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        historyItem['competition'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Color(0xFFFFE6AC),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Lexend',
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          
                          // Match content - Teams and Score
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                                // Home Team
                                Column(
                                  children: [
                                    historyItem['homeTeamLogo'] != null && historyItem['homeTeamLogo'].isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.network(
                                            football_api.FootballApiService.getProxyImageUrl(historyItem['homeTeamLogo']),
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 48, 
                                                height: 48,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(Icons.sports_soccer, size: 24, color: colorScheme.onSurfaceVariant),
                                              );
                                            },
                                          ),
                                        )
                                      : Container(
                                          width: 48,
                                          height: 48,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(Icons.sports_soccer, size: 24, color: colorScheme.onSurfaceVariant),
                                        ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        historyItem['homeTeamShortName'] ?? historyItem['homeTeam'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          fontFamily: 'Lexend',
                                          color: isDarkMode ? Colors.white : Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (matchStatus == 'IN_PLAY' || matchStatus == 'PAUSED')
                                      Text(
                                        '⚽',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white70 : Colors.black54,
                                          fontSize: 10,
                                          fontFamily: 'Lexend',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                  ],
                                ),
                                
                                // Center - Score/Status
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasScore || matchStatus == 'IN_PLAY' || matchStatus == 'PAUSED' || matchStatus == 'FINISHED')
                            Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                          color: matchStatus == 'IN_PLAY' || matchStatus == 'PAUSED'
                                            ? Colors.red.withOpacity(0.1)
                                            : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          scoreText,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: matchStatus == 'IN_PLAY' || matchStatus == 'PAUSED'
                                              ? Colors.red
                                              : (isDarkMode ? Colors.white : Colors.black),
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        scoreText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDarkMode ? Colors.white : Colors.black,
                                        ),
                                      ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    // Date/Time info
                                    if (matchStatus == 'TIMED' || matchStatus == 'SCHEDULED')
                                      Column(
                                        children: [
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              color: isDarkMode ? Colors.white70 : Colors.grey[700],
                                              fontSize: 10,
                                              fontFamily: 'Lexend',
                                            ),
                                          ),
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              color: isDarkMode ? Colors.white70 : Colors.grey[700],
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Lexend',
                                            ),
                                          ),
                                        ],
                                      )
                                    else if (matchStatus == 'IN_PLAY' || matchStatus == 'PAUSED')
                                      Text(
                                        matchStatus == 'PAUSED' ? 'HT' : 'LIVE',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Lexend',
                                        ),
                                      )
                                    else if (matchStatus == 'FINISHED')
                                      Text(
                                        'FT',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Lexend',
                                        ),
                                      )
                                    else
                                      Text(
                                        _getStatusText(matchStatus),
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Lexend',
                                        ),
                                      ),
                                  ],
                                ),
                                
                                // Away Team
                                Column(
                                  children: [
                                    historyItem['awayTeamLogo'] != null && historyItem['awayTeamLogo'].isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.network(
                                            football_api.FootballApiService.getProxyImageUrl(historyItem['awayTeamLogo']),
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                width: 48, 
                                                height: 48,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(Icons.sports_soccer, size: 24, color: colorScheme.onSurfaceVariant),
                                              );
                                            },
                                          ),
                                        )
                                      : Container(
                                          width: 48,
                                          height: 48,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(Icons.sports_soccer, size: 24, color: colorScheme.onSurfaceVariant),
                                        ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        historyItem['awayTeamShortName'] ?? historyItem['awayTeam'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          fontFamily: 'Lexend',
                                          color: isDarkMode ? Colors.white : Colors.black,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (matchStatus == 'IN_PLAY' || matchStatus == 'PAUSED')
                                      Text(
                                        '⚽',
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white70 : Colors.black54,
                                          fontSize: 10,
                                          fontFamily: 'Lexend',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                // For teams and competitions, use a simpler card
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  color: isDarkMode ? const Color(0xFF292929) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _navigateToHistoryItem(context, historyItem),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Team/League logo without circle background
                              if (historyItem['emblem'] != null && historyItem['emblem'].isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      kIsWeb
                                        ? 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(historyItem['emblem'])}'
                                        : historyItem['emblem'],
                                      fit: BoxFit.contain,
                                      width: 36,
                                      height: 36,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        type == 'team' ? Icons.group : Icons.emoji_events,
                                        size: 36,
                                        color: isDarkMode ? Colors.white60 : Colors.black45,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: Icon(
                                    type == 'team' ? Icons.group : Icons.emoji_events,
                                    size: 36,
                                    color: isDarkMode ? Colors.white60 : Colors.black45,
                                  ),
                                ),
                              
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    historyItem['name'],
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black,
                                        fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                        fontFamily: 'Lexend',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: type == 'team' 
                                          ? const Color(0xFFFFE6AC).withOpacity(0.2)
                                          : Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        type == 'team' ? 'Team' : 'League',
                                    style: TextStyle(
                                          color: type == 'team' ? const Color(0xFFFFE6AC) : Colors.green,
                                          fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                          fontFamily: 'Lexend',
                                        ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                              
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: isDarkMode ? Colors.white60 : Colors.black45,
                            ),
                          ],
                        ),
                        ),
                      ],
                      ),
                    ),
                  );
                },
            ),
          ),
        ],
      );
    }
    
    // Default initial screen if no history
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: const Color(0xFFFFE6AC),
          ),
          const SizedBox(height: 16),
          Text(
            'Start typing to search for teams and leagues',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 16,
              fontFamily: 'Lexend',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to navigate based on history item type
  void _navigateToHistoryItem(BuildContext context, Map<String, dynamic> historyItem) {
    final String type = historyItem['type'];
    
    switch (type) {
      case 'team':
        final String id = historyItem['id'].toString();
        final String name = historyItem['name'];
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeamDetailsPage(
              teamId: id,
              teamName: name,
            ),
          ),
        );
        break;
      case 'competition':
        // For now, set this as search query and show results
        query = historyItem['name'];
        showResults(context);
        break;
      case 'match':
        // Navigate to match details
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchDetailsPage(matchData: {
              'id': int.tryParse(historyItem['id'].toString()) ?? 0,
              'homeTeam': {
                'name': historyItem['homeTeam'],
                'id': historyItem['homeTeamId'] != null ? int.tryParse(historyItem['homeTeamId'].toString()) ?? 0 : 0,
                'crest': historyItem['homeTeamLogo'] ?? '',
              },
              'awayTeam': {
                'name': historyItem['awayTeam'],
                'id': historyItem['awayTeamId'] != null ? int.tryParse(historyItem['awayTeamId'].toString()) ?? 0 : 0,
                'crest': historyItem['awayTeamLogo'] ?? '',
              },
              'status': historyItem['status'],
              'score': historyItem['score'],
              'competition': {
                'name': historyItem['competition'],
                'id': historyItem['competitionId'] != null ? int.tryParse(historyItem['competitionId'].toString()) ?? 0 : 0,
                'emblem': historyItem['competitionEmblem'],
              },
              'utcDate': historyItem['date'] ?? historyItem['utcDate'],
            }),
          ),
        );
        break;
    }
  }

  // Helper method to get proxied image URL for logos
  String getProxiedImageUrl(String? originalUrl) {
    // Use the centralized method from the FootballApiService
    return football_api.FootballApiService.getProxyImageUrl(originalUrl);
  }

  // Helper method to show minimum characters message
  Widget _buildMinimumCharactersMessage(BuildContext context, bool isDarkMode, ColorScheme colorScheme) {
    final currentQuery = super.query;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Please enter at least 3 characters',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Current query: "${currentQuery}" (${currentQuery.length}/3)',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method that handles caching for search results
  Future<List<Map<String, dynamic>>> _getSearchResults(String query) async {
    // Use cached results if available
    if (_searchCache.containsKey(query)) {
      print("[_getSearchResults] Using cached results for '$query'");
      return _searchCache[query]!;
    }
    
    // Otherwise perform new search
    final results = await _searchData(query);
    
    // Cache the results
    _searchCache[query] = results;
    
    return results;
  }

  // Helper method to build a search result item with an improved UI
  Widget _buildSearchResultItem(BuildContext context, Map<String, dynamic> item, bool isDarkMode, ColorScheme colorScheme) {
    final itemType = item['type'] as String;

    // Get appropriate icon based on item type
    IconData getItemTypeIcon() {
      switch (itemType) {
        case 'team':
          return Icons.group;
        case 'match':
          return Icons.sports_soccer;
        case 'competition':
          return Icons.emoji_events;
        default:
          return Icons.search;
      }
    }

    // Get the item's emblem or logo
    Widget getItemLogo() {
      // Choose the right logo based on item type
      String? logoUrl;
      
      if (itemType == 'match') {
        // For matches, use the competition emblem if available
        logoUrl = item['competitionEmblem'];
      } else {
        // For teams and competitions, use the emblem
        logoUrl = item['emblem'];
      }
      
      if (logoUrl != null && logoUrl.isNotEmpty) {
        final String proxyUrl = football_api.FootballApiService.getProxyImageUrl(logoUrl);
        print('Loading logo: $logoUrl via $proxyUrl');
          
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            proxyUrl,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading logo: $error for URL: $proxyUrl');
              return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              getItemTypeIcon(),
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
              );
            },
          ),
        );
      } else {
        // Fallback icon inside a colored container
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            getItemTypeIcon(),
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        );
      }
    }

    // For match items, show additional team logos
    Widget? getTeamLogos() {
      if (itemType != 'match') return null;
      
      // Debug print item structure
      print('Match Item: ${jsonEncode(item)}');
      
      // Home team logo processing
      final String? homeTeamLogo = item['homeTeamLogo'];
      final String homeProxyUrl = football_api.FootballApiService.getProxyImageUrl(homeTeamLogo);
      print('Home Team Logo: $homeTeamLogo, Proxy URL: $homeProxyUrl');
        
      // Away team logo processing
      final String? awayTeamLogo = item['awayTeamLogo'];
      final String awayProxyUrl = football_api.FootballApiService.getProxyImageUrl(awayTeamLogo);
      print('Away Team Logo: $awayTeamLogo, Proxy URL: $awayProxyUrl');
      
      // Get score information if available
      var homeScore, awayScore;
      if (item.containsKey('score') && item['score'] != null) {
        if (item['score'].containsKey('fullTime') && item['score']['fullTime'] != null) {
          homeScore = item['score']['fullTime']['home'];
          awayScore = item['score']['fullTime']['away'];
        }
      }
      final hasScore = homeScore != null && awayScore != null;
      final matchStatus = item['status']?.toString().toUpperCase() ?? '';
      final scoreText = hasScore ? '$homeScore - $awayScore' : 'vs';
      
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
            // Home Team
            Column(
              children: [
                homeTeamLogo != null && homeTeamLogo.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        homeProxyUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading home team logo: $error, URL: $homeTeamLogo, Proxy: $homeProxyUrl');
                          return Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                      decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.sports_soccer, size: 24, color: colorScheme.onSurfaceVariant),
                          );
                        },
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.sports_soccer, size: 24, color: colorScheme.onSurfaceVariant),
                    ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: Text(
                    item['homeTeamShortName'] ?? item['homeTeam'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Lexend',
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Match Status/Score
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (['IN_PLAY', 'LIVE'].contains(matchStatus))
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                          color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Lexend',
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
          Text(
                        scoreText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          fontFamily: 'Lexend',
                          color: Color(0xFFFFE6AC),
                        ),
                      ),
                    ],
                  )
                else if (['PAUSED', 'HALF_TIME'].contains(matchStatus))
                  Column(
                    children: [
                      Text(
                        'HT',
            style: TextStyle(
                          color: isDarkMode ? Colors.yellow : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          fontFamily: 'Lexend',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scoreText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          fontFamily: 'Lexend',
                          color: Color(0xFFFFE6AC),
                        ),
                      ),
                    ],
                  )
                else if (['FINISHED', 'FT'].contains(matchStatus))
                  Column(
                    children: [
                      Text(
                        'FT',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          fontFamily: 'Lexend',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scoreText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          fontFamily: 'Lexend',
                          color: Color(0xFFFFE6AC),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'vs',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Lexend',
                        color: Color(0xFFFFE6AC),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 6),
                
                // Date/Time
                if (item['date'] != null)
                  Text(
                    _formatMatchDateTime(item['date']),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 10,
                      fontFamily: 'Lexend',
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
            
            // Away Team
            Column(
              children: [
                awayTeamLogo != null && awayTeamLogo.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        awayProxyUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading away team logo: $error, URL: $awayTeamLogo, Proxy: $awayProxyUrl');
                          return Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                      decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                      ),
                            child: Icon(Icons.sports_soccer, size: 24, color: colorScheme.onSurfaceVariant),
                          );
                        },
                    ),
                  )
                : Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.sports_soccer, size: 24, color: colorScheme.onSurfaceVariant),
                    ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: Text(
                    item['awayTeamShortName'] ?? item['awayTeam'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: 'Lexend',
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
            ),
          ],
        ),
      );
    }
    
    // Navigate based on item type
    void onTap() {
      // Remember query before navigating
      _lastQuery = super.query;
      
      switch (itemType) {
        case 'team':
          // Add to search history
          addToHistory(item);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeamDetailsPage(
                teamId: item['id'].toString(),
                teamName: item['name'],
              ),
            ),
          );
          break;
        case 'match':
          // Add to search history - call directly with the current item
          addToHistory(item);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchDetailsPage(matchData: {
                'id': int.tryParse(item['id'].toString()) ?? 0,
                'homeTeam': {
                  'name': item['homeTeam'],
                  'id': item['homeTeamId'] != null ? int.tryParse(item['homeTeamId'].toString()) ?? 0 : 0,
                  'crest': item['homeTeamLogo'] ?? '',
                },
                'awayTeam': {
                  'name': item['awayTeam'],
                  'id': item['awayTeamId'] != null ? int.tryParse(item['awayTeamId'].toString()) ?? 0 : 0,
                  'crest': item['awayTeamLogo'] ?? '',
                },
                'status': item['status'],
                'score': item['score'],
                'competition': {
                  'name': item['competition'],
                  'id': item['competitionId'] != null ? int.tryParse(item['competitionId'].toString()) ?? 0 : 0,
                  'emblem': item['competitionEmblem'],
                },
                'utcDate': item['date'] ?? item['utcDate'],
              }),
            ),
          );
          break;
        case 'competition':
          // Add to search history
          addToHistory(item);
          
          // For competitions (leagues), just update the query to see related data
          // We could also navigate to a competition page in the future
          final competitionName = item['name'];
          query = competitionName;
          showResults(context);
          break;
        default:
          query = item['name'];
          showResults(context);
      }
    }

    return itemType != 'match' ? 
      // For teams and competitions, use the exact same card structure as in search history
      Card(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        elevation: 3,
      color: isDarkMode ? const Color(0xFF292929) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
            child: Row(
            children: [
                // Team or competition logo
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      football_api.FootballApiService.getProxyImageUrl(item['emblem'] ?? ''),
                      width: 36, 
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            itemType == 'team' ? Icons.group : Icons.emoji_events,
                            size: 24,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                      children: [
                      Text(
                        item['name'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Lexend',
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: itemType == 'team' 
                            ? const Color(0xFFFFE6AC).withOpacity(0.2)
                            : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          itemType == 'team' ? 'Team' : 'League',
                          style: TextStyle(
                            color: itemType == 'team' ? const Color(0xFFFFE6AC) : Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Lexend',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: isDarkMode ? Colors.white60 : Colors.black45,
                ),
              ],
            ),
          ),
        ),
      )
      : Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 3,
        color: isDarkMode ? const Color(0xFF292929) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with competition info
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                        color: const Color(0xFFFFE6AC).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                        'MATCH',
                        style: const TextStyle(
                          color: Color(0xFFFFE6AC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    if (item['status'] != null)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(item['status'], isDarkMode),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getStatusText(item['status']),
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.black : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                            fontFamily: 'Lexend',
                                  ),
                                ),
                              ),
                    const Spacer(),
                    if (item['competitionEmblem'] != null && item['competitionEmblem'].isNotEmpty)
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              football_api.FootballApiService.getProxyImageUrl(item['competitionEmblem']),
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                print('Error loading competition emblem: $error');
                                return const Icon(Icons.emoji_events, size: 24);
                              },
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item['competition'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Color(0xFFFFE6AC),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Lexend',
                            ),
                          ),
                      ],
                  ),
                ],
              ),
                ),
              
              // Match content
              getTeamLogos() ?? const SizedBox.shrink()
            ],
        ),
      ),
    );
  }

  // Helper method to get status color
  Color _getStatusColor(String status, bool isDarkMode) {
    switch (status) {
      case 'FINISHED':
        return Colors.green;
      case 'IN_PLAY':
      case 'PAUSED':
        return Colors.red;
      case 'TIMED':
      case 'SCHEDULED':
        return isDarkMode ? Colors.blue : Colors.blue;
      case 'POSTPONED':
      case 'CANCELLED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Helper method to get readable status text
  String _getStatusText(String status) {
    switch (status) {
      case 'FINISHED':
        return 'FINISHED';
      case 'IN_PLAY':
        return 'LIVE';
      case 'PAUSED':
        return 'PAUSED';
      case 'TIMED':
      case 'SCHEDULED':
        return 'UPCOMING';
      case 'POSTPONED':
        return 'POSTPONED';
      case 'CANCELLED':
        return 'CANCELLED';
      default:
        return status;
    }
  }

  Future<List<Map<String, dynamic>>> _searchData(String query) async {
    // Log the query received by _searchData
    print("[_searchData] Received query: '$query'");

    if (query.isEmpty) {
      print("[_searchData] Query is empty, returning empty list.");
      return [];
    }

    print("[_searchData] Starting search for: '$query'");

    try {
      // First, search for teams since we want to prioritize them
      print("[_searchData] Calling searchTeams for '$query'...");
      final teams = await football_api.FootballApiService.searchTeams(query);
      print("[_searchData] Found ${teams.length} teams for '$query'.");
      
      // Search competitions
      print("[_searchData] Calling searchCompetitions for '$query'...");
      final competitions = await football_api.FootballApiService.searchCompetitions(query);
      print("[_searchData] Found ${competitions.length} competitions for '$query'.");

      // Search matches last
      print("[_searchData] Calling searchMatches for '$query'...");
      final matches = await football_api.FootballApiService.searchMatches(query);
      print("[_searchData] Found ${matches.length} matches for '$query'.");
      
      // Debug print for match data structure to troubleshoot logo issue
      if (matches.isNotEmpty) {
        print('Match structure from API: ${jsonEncode(matches[0])}');
      }

      // Create the results lists separately to apply different sorting logic
      final teamResults = teams.map((t) => {
          'id': t['id'],
          'name': t['name'] ?? 'Unknown Team',
          'emblem': t['emblem'] ?? '',
          'type': 'team',
        // Add a relevance score
        '_relevance': _calculateRelevance(t['name'] ?? '', query),
      }).toList();
      
      final competitionResults = competitions.map((c) => {
          'id': c['id'],
          'name': c['name'] ?? 'Unknown Competition',
          'emblem': c['emblem'] ?? '',
          'type': 'competition',
        // Add a relevance score with a slight boost for competitions
        '_relevance': _calculateRelevance(c['name'] ?? '', query) * 1.1,
      }).toList();
      
      final matchResults = matches.map((m) => {
        'id': m['id'],
        'name': m['status'] == 'FINISHED' 
          ? '${m['homeTeam']} ${m['score']['fullTime']['home'] ?? 0} - ${m['score']['fullTime']['away'] ?? 0} ${m['awayTeam']}'
          : '${m['homeTeam']} vs ${m['awayTeam']}',
        'homeTeam': m['homeTeam'] ?? 'N/A',
        'awayTeam': m['awayTeam'] ?? 'N/A',
        'homeTeamShortName': m['homeTeamShortName'] ?? m['homeTeam'] ?? 'N/A',
        'awayTeamShortName': m['awayTeamShortName'] ?? m['awayTeam'] ?? 'N/A',
        'homeTeamId': m['homeTeamId'],
        'awayTeamId': m['awayTeamId'],
        'homeTeamLogo': m['homeTeamLogo'],
        'awayTeamLogo': m['awayTeamLogo'],
        'competition': m['competition'] ?? 'N/A',
        'competitionId': m['competitionId'],
        'competitionEmblem': m['competitionEmblem'],
        'date': m['date'],
        'status': m['status'],
        'score': m['score'],
        'type': 'match',
        // Add a relevance score for matches
        '_relevance': _calculateRelevance(m['homeTeam'] ?? '', query) * 0.8 + 
                      _calculateRelevance(m['awayTeam'] ?? '', query) * 0.8,
      }).toList();

      // Sort each list by relevance
      teamResults.sort((a, b) => (b['_relevance'] as num).compareTo(a['_relevance'] as num));
      competitionResults.sort((a, b) => (b['_relevance'] as num).compareTo(a['_relevance'] as num));
      matchResults.sort((a, b) => (b['_relevance'] as num).compareTo(a['_relevance'] as num));

      // Check if we have exact competition (league) matches to prioritize
      final exactCompetitionMatches = competitionResults.where((comp) => 
        comp['name'].toString().toLowerCase() == query.toLowerCase()
      ).toList();
      
      if (exactCompetitionMatches.isNotEmpty) {
        final exactCompetition = exactCompetitionMatches.first;
        
        // Create combined results with the competition first
        final results = [
          exactCompetition,
          ...competitionResults.where((comp) => comp['id'] != exactCompetition['id']).toList(),
          ...teamResults,
          ...matchResults,
        ];
        
        print("[_searchData] Returning ${results.length} results with prioritized competition for '$query'.");
        return results;
      }

      // Check if we have exact team matches to prioritize
      final exactTeamMatches = teamResults.where((team) => 
        team['name'].toString().toLowerCase() == query.toLowerCase()
      ).toList();
      
      // If we have exact team matches and also found matches, 
      // prioritize the team first, then filter matches for that team
      if (exactTeamMatches.isNotEmpty && matchResults.isNotEmpty) {
        final exactTeam = exactTeamMatches.first;
        final exactTeamId = exactTeam['id'];
        
        // Find matches for this exact team
        final teamMatches = matchResults.where((match) => 
          match['homeTeamId'] == exactTeamId || match['awayTeamId'] == exactTeamId
        ).toList();
        
        // Sort team matches - make sure most recent/upcoming are first
        teamMatches.sort((a, b) {
          // First by status (live, upcoming, finished)
          final statusA = a['status'] as String;
          final statusB = b['status'] as String;
          
          // Live matches first
          if (statusA == 'IN_PLAY' && statusB != 'IN_PLAY') return -1;
          if (statusA != 'IN_PLAY' && statusB == 'IN_PLAY') return 1;
          
          // Then upcoming matches
          if (statusA == 'TIMED' && statusB != 'TIMED') return -1;
          if (statusA != 'TIMED' && statusB == 'TIMED') return 1;
          
          // Sort by date
          if (a['date'] != null && b['date'] != null) {
            return DateTime.parse(b['date'] as String)
                .compareTo(DateTime.parse(a['date'] as String));
          }
          
          return 0;
        });
        
        // Filter out the team matches from the main match results
        final otherMatches = matchResults.where((match) => 
          match['homeTeamId'] != exactTeamId && match['awayTeamId'] != exactTeamId
        ).toList();
        
        // Combine results: exact team first, then its matches, then other results
        final results = [
          exactTeam,
          ...teamMatches,
          ...teamResults.where((team) => team['id'] != exactTeamId).toList(),
          ...competitionResults,
          ...otherMatches,
        ];
        
        print("[_searchData] Returning ${results.length} results with prioritized team first for '$query'.");
      return results;
      }

      // Normal case - combine and sort all results by relevance
      List<Map<String, dynamic>> allResults = [
        ...teamResults,
        ...competitionResults,
        ...matchResults,
      ];
      
      // Final sort by relevance score
      allResults.sort((a, b) => (b['_relevance'] as num).compareTo(a['_relevance'] as num));

      print("[_searchData] Returning ${allResults.length} sorted results for '$query'.");
      return allResults;
      
    } catch (e, stacktrace) {
      print('[_searchData] Search error for query "$query": $e');
      print('[_searchData] Stacktrace: $stacktrace');
      return [];
    }
  }
  
  // Helper method to calculate relevance score for sorting
  double _calculateRelevance(String text, String query) {
    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    
    // Exact match gets highest score
    if (textLower == queryLower) {
      return 100.0;
    }
    
    // Contains exact query as a whole word
    if (textLower.contains(' $queryLower ') || 
        textLower.startsWith('$queryLower ') || 
        textLower.endsWith(' $queryLower')) {
      return 80.0;
    }
    
    // Starts with query
    if (textLower.startsWith(queryLower)) {
      return 60.0;
    }
    
    // Contains query
    if (textLower.contains(queryLower)) {
      return 40.0;
    }
    
    // Calculate word match count
    final textWords = textLower.split(' ');
    final queryWords = queryLower.split(' ');
    int matchCount = 0;
    
    for (final queryWord in queryWords) {
      if (queryWord.length > 2) { // Only consider words longer than 2 chars
        for (final textWord in textWords) {
          if (textWord.contains(queryWord)) {
            matchCount++;
            break;
          }
        }
      }
    }
    
    return matchCount * 5.0;
  }

  @override
  void dispose() {
    _debounce?.cancel(); // Important: cancel timer on dispose
    super.dispose();
  }

  // Add a helper method to format match date/time
  String _formatMatchDateTime(String? utcDate) {
    if (utcDate == null) return 'Date unknown';
    
    try {
      final date = DateTime.parse(utcDate);
      final now = DateTime.now();
      final difference = date.difference(now).inDays;
      
      // Format the date part
      String datePart;
      if (difference == 0) {
        datePart = 'Today';
      } else if (difference == 1) {
        datePart = 'Tomorrow';
      } else if (difference == -1) {
        datePart = 'Yesterday';
      } else {
        // Format as day name + date
        final formatter = DateFormat('EEE, MMM d');
        datePart = formatter.format(date);
      }
      
      // Format the time part
      final timeFormatter = DateFormat('HH:mm');
      final timePart = timeFormatter.format(date.toLocal());
      
      return '$datePart at $timePart';
    } catch (e) {
      return 'Date unknown';
    }
  }

  // Helper for Match History Card: Status/Score Display
  Widget _buildMatchHistoryStatus(BuildContext context, String matchStatus, bool hasScore, dynamic homeScore, dynamic awayScore) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    switch (matchStatus.toUpperCase()) {
      case 'IN_PLAY':
      case 'LIVE':
        return Column(
          children: [
            Text(
              'LIVE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              hasScore ? '$homeScore - $awayScore' : '- : -', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        );
      case 'PAUSED':
      case 'HALF_TIME':
        return Column(
          children: [
            Text(
              'HT',
              style: TextStyle(color: isDarkMode ? Colors.yellow : Colors.orange, fontWeight: FontWeight.bold, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              hasScore ? '$homeScore - $awayScore' : '- : -', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        );
      case 'FINISHED':
      case 'FT':
        return Column(
          children: [
            Text(
              'FT',
              style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              hasScore ? '$homeScore - $awayScore' : '- : -', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        );
      default: // SCHEDULED, TIMED, POSTPONED, etc.
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'vs',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        );
    }
  }

  // Helper for Match History Card: Date/Time Display
  Widget _buildMatchHistoryDateTime(BuildContext context, String matchStatus, String formattedDate, String formattedTime, bool isDarkMode) {
    TextStyle defaultStyle = TextStyle(
      color: isDarkMode ? Colors.white70 : Colors.black54,
      fontSize: 10,
    );
    TextStyle boldStyle = defaultStyle.copyWith(fontWeight: FontWeight.bold);

    // Show date/time only for scheduled/default cases
    switch(matchStatus.toUpperCase()) {
      case 'TIMED':
      case 'SCHEDULED':
        return Column(
          children: [
            Text(formattedDate, style: defaultStyle),
            Text(formattedTime, style: boldStyle),
          ],
        );
      case 'POSTPONED':
        return Text(
          'PST',
          style: TextStyle(color: Colors.grey, fontSize: 10)
        );
      case 'SUSPENDED':
        return Text(
          'SUS',
          style: TextStyle(color: Colors.orange, fontSize: 10)
        );
      case 'CANCELLED':
        return Text(
          'CAN',
          style: TextStyle(color: Colors.red, fontSize: 10)
        );
      default: // Hide date/time for ongoing/finished matches
        return const SizedBox.shrink();
    }
  }

  // Format match date/time - keeping a different name to avoid duplication
  String _formatMatchDateTimeAlt(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return 'Unknown date';
    }
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final yesterday = today.subtract(const Duration(days: 1));
      final matchDate = DateTime(date.year, date.month, date.day);
      
      String dateText;
      if (matchDate == today) {
        dateText = 'Today';
      } else if (matchDate == tomorrow) {
        dateText = 'Tomorrow';
      } else if (matchDate == yesterday) {
        dateText = 'Yesterday';
      } else {
        // Format like "Mar 15, 2023"
        dateText = DateFormat('MMM d, yyyy').format(date);
      }
      
      // Add time: "Today, 15:00"
      return '$dateText, ${DateFormat('HH:mm').format(date)}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}

// A clean loading screen with just a pulsating SVG logo
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

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
            MaterialPageRoute(builder: (context) => const DashboardPage()),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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

// Add these helper methods at the end of the CustomSearchDelegate class

// Helper method to build team logo
Widget _buildTeamLogo(String? emblemUrl, double size, bool isDarkMode, ColorScheme colorScheme) {
  if (emblemUrl == null || emblemUrl.isEmpty) {
    return Icon(
      Icons.sports_soccer,
      size: size,
      color: isDarkMode ? Colors.white60 : Colors.black45,
    );
  }

  // Use the same proxy approach as the dashboard
  final String proxyUrl = kIsWeb
      ? 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(emblemUrl)}'
      : emblemUrl;
  
  // Use direct Image.network for reliability
  return ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Image.network(
      proxyUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.sports_soccer,
        size: size,
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

// Local proxy URL helper
String _getProxyUrl(String? originalUrl) {
  if (originalUrl == null || originalUrl.isEmpty) {
    return '';
  }
  
  // Match the app's standard implementation
  if (kIsWeb) {
    // Proxy through Firebase function for web
    return 'https://us-central1-footify-13da4.cloudfunctions.net/proxyImage?url=${Uri.encodeComponent(originalUrl)}';
  }
  // Use direct URL for mobile
  return originalUrl;
}

// Helper method to get short team name
String _getShortTeamName(Map<String, dynamic> team) {
  // First try to use shortName if it exists
  final shortName = team['shortName'];
  if (shortName != null && shortName is String && shortName.isNotEmpty) {
    return shortName;
  }
  
  // Otherwise use team name and truncate if needed
  final name = team['name'] as String;
  
  // If name is longer than 12 chars, try to create shortened version
  if (name.length > 12) {
    // Try to split on common words and abbreviate
    if (name.contains(' FC')) {
      return name.replaceAll(' FC', '');
    } else if (name.contains(' CF')) {
      return name.replaceAll(' CF', '');
    } else if (name.contains('United')) {
      return name.replaceAll('United', 'Utd');
    } else if (name.contains('Manchester')) {
      return name.replaceAll('Manchester', 'Man');
    } else if (name.contains('City')) {
      return name.replaceAll('City', 'C');
    } else {
      // Return first 10 chars with ellipsis
      return name.length > 10 ? '${name.substring(0, 10)}…' : name;
    }
  }
  
  return name;
}

// Helper method to add a item to search history
void addToHistory(Map<String, dynamic> item) async {
  final prefs = await SharedPreferences.getInstance();
  final String type = item['type'];
  List<String> history = prefs.getStringList('search_history') ?? [];
  
  // Debug print to track what we're adding
  print('Adding to history: ${json.encode(item)}');
  
  // Convert the item to a simple map for storage
  Map<String, dynamic> historyItem;
  
  if (type == 'match') {
    // For match items, store necessary info
    historyItem = {
      'id': item['id'],
      'type': 'match',
      'name': item['name'],
      'homeTeam': {
        'name': item['homeTeam'],
        'emblem': item['homeTeamLogo'] ?? '',
      },
      'awayTeam': {
        'name': item['awayTeam'],
        'emblem': item['awayTeamLogo'] ?? '',
      },
      'homeTeamShortName': item['homeTeamShortName'] ?? item['homeTeam'],
      'awayTeamShortName': item['awayTeamShortName'] ?? item['awayTeam'],
      'homeTeamId': item['homeTeamId'] ?? '',
      'awayTeamId': item['awayTeamId'] ?? '',
      'date': item['date'] ?? item['utcDate'],
      'status': item['status'],
      'score': item['score'],
      'competition': item['competition'],
      'competitionId': item['competitionId'] ?? '',
      'competitionEmblem': item['competitionEmblem'] ?? '',
    };
  } else {
    // For team and competition items
    historyItem = {
      'id': item['id'],
      'type': type,
      'name': item['name'],
      'emblem': item['emblem'] ?? '',
    };
  }
  
  final String itemJson = jsonEncode(historyItem);
  
  // Check if the item is already in history
  final existingIndex = history.indexWhere((element) {
    try {
      final decoded = jsonDecode(element);
      return decoded['id'].toString() == item['id'].toString() && decoded['type'] == type;
    } catch (e) {
      return false;
    }
  });
  
  // If found, remove it so we can add it to the top
  if (existingIndex != -1) {
    history.removeAt(existingIndex);
  }
  
  // Add to the beginning of the list
  history.insert(0, itemJson);
  
  // Limit to 20 items
  if (history.length > 20) {
    history = history.sublist(0, 20);
  }
  
  // Save back to SharedPreferences
  await prefs.setStringList('search_history', history);
}