// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'main.dart';
import 'calendar.dart';
import 'leagues.dart';
import 'profile.dart';
import 'settings.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'language_provider.dart';
import 'package:provider/provider.dart';
import 'providers/firebase_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CommonLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final bool useMaxWidth;
  final bool showBackButton;

  const CommonLayout({
    Key? key, 
    required this.child,
    required this.selectedIndex,
    this.useMaxWidth = true,
    this.showBackButton = false,
  }) : super(key: key);

  void _onItemTapped(BuildContext context, int index) {
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
        page = const MainScreen();
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
    final isLoggedIn = Provider.of<FirebaseProvider>(context).currentUser != null;
    final isWeb = MediaQuery.of(context).size.width > 800;

    Widget mainContent = child;

    if (isWeb && useMaxWidth) {
      mainContent = Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(),
          ),
          Container(
            width: 1000,
            child: child,
          ),
          Expanded(
            flex: 1,
            child: Container(),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1F1E1F) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1F1E1F) : Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        forceMaterialTransparency: false,
        leading: showBackButton 
          ? IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 30,
              ),
              padding: const EdgeInsets.only(top: 20),
              onPressed: () {
                Navigator.pop(context);
              },
            )
          : null,
        title: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding: EdgeInsets.only(left: showBackButton ? 0 : 16),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainScreen()),
                    );
                  },
                  child: _buildResponsiveLogo(context, isDarkMode),
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.search, color: isDarkMode ? Colors.white : Colors.black),
                iconSize: 24,
                constraints: BoxConstraints(maxWidth: 34, maxHeight: 34),
                padding: EdgeInsets.zero,
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: CustomSearchDelegate(),
                  );
                },
              ),
              if (isLoggedIn)
                IconButton(
                  icon: Icon(
                    Icons.notifications,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  iconSize: 24,
                  constraints: BoxConstraints(maxWidth: 34, maxHeight: 34),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    // Handle notifications
                  },
                )
              else
                SizedBox(
                  width: 80,
                  child: TextButton(
                    onPressed: () {
                      // Navigate to profile/login page
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const ProfilePage(),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.loginRegister,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
                  colors: [
                    Color(0xFF1D1D1D),
                    Color(0xFF232323),
                    Color(0xFF262626),
                    Color(0xFF292929)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.3, 0.7, 1.0],
                )
              : const LinearGradient(
                  colors: [Colors.white, Color(0xFFF8F8F8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Divider(
              color: Color(0xFFFFE6AC),
              thickness: 3,
            ),
            Expanded(child: mainContent),
          ],
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: isDarkMode ? const Color(0xFF1D1D1B) : Colors.white,
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => _onItemTapped(context, index),
          selectedItemColor: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black,
          unselectedItemColor: isDarkMode ? Colors.white : Colors.black,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: AppLocalizations.of(context)!.home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month),
              label: AppLocalizations.of(context)!.calendar,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.emoji_events),
              label: AppLocalizations.of(context)!.league,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: AppLocalizations.of(context)!.profile,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings),
              label: AppLocalizations.of(context)!.settings,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build a responsive logo
  Widget _buildResponsiveLogo(BuildContext context, bool isDarkMode) {
    // Always use the full logo regardless of screen size
    String logoAsset = isDarkMode 
      ? 'assets/images/footify_logo_optimized_dark.svg' 
      : 'assets/images/footify_logo_optimized_light.svg';
    
    final logoWidth = 120.0;
    final logoHeight = 90.0;
    
    return SvgPicture.asset(
      logoAsset,
      width: logoWidth,
      height: logoHeight,
      fit: BoxFit.contain,
    );
  }
}