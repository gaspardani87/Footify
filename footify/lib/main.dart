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

    return MaterialApp(
      title: 'Footify',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(ThemeData.light(), fontSizeProvider.fontSize, Provider.of<ColorBlindModeProvider>(context).isColorBlindMode),
      darkTheme: _buildTheme(ThemeData.dark(), fontSizeProvider.fontSize, Provider.of<ColorBlindModeProvider>(context).isColorBlindMode),
      themeMode: themeProvider.themeMode, // Use the selected theme mode
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