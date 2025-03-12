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

class CommonLayout extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final bool useMaxWidth;

  const CommonLayout({
    Key? key, 
    required this.child,
    required this.selectedIndex,
    this.useMaxWidth = true,
  }) : super(key: key);

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
            width: 1200,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? const LinearGradient(
                  colors: [Color(0xFF1D1D1D), Color(0xFF292929)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : const LinearGradient(
                  colors: [Colors.white, Colors.white],
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
                        if (isLoggedIn)
                          IconButton(
                            icon: Icon(
                              Icons.notifications,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            onPressed: () {
                              // Handle notifications
                            },
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
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
                              child: Text(
                                'Login/Register',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
}