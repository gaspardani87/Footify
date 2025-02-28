// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'main.dart';
import 'calendar.dart';
import 'leagues.dart';
import 'profile.dart';
import 'settings.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'language_provider.dart';

class CommonLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;

  const CommonLayout({super.key, required this.child, required this.selectedIndex});

  void _onItemTapped(BuildContext context, int index) {
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
                  colors: [Color(0xFF1D1D1D), Color(0xFF292929)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : const LinearGradient(
                  colors: [Colors.white, Colors.white], // Light mode background
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: Column(
          children: [
            AppBar(
              backgroundColor: isDarkMode ? Colors.transparent : Colors.white,
              elevation: 0,
              title: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomePage()),
                        );
                      },
                      child: Image.asset(
                        isDarkMode ? 'assets/images/kicsiFootify-Logo-NoBG-LightMode.png' : 'assets/images/Footify-Logo-NoBG_szerk_hosszu_logo-01.png',
                        width: 120,
                        height: 120,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.search, color: isDarkMode ? Colors.white : Colors.black),
                          iconSize: 30,
                          onPressed: () {
                            showSearch(
                              context: context,
                              delegate: CustomSearchDelegate(),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.notifications, color: isDarkMode ? Colors.white : Colors.black),
                          iconSize: 30,
                          onPressed: () {
                            // Add your notification functionality here
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(
              color: Color(0xFFFFE6AC),
              thickness: 3,
            ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: isDarkMode ? const Color(0xFF1D1D1B) : Colors.white, // Light mode background
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => _onItemTapped(context, index),
          selectedItemColor: isDarkMode ? const Color(0xFFFFE6AC) : Colors.black, // Light mode accent color
          unselectedItemColor: isDarkMode ? Colors.white : Colors.black, // Light mode text color
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
}