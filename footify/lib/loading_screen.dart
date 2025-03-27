import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'main.dart';
import 'dashboard.dart';

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
    // Use a smooth animation duration for subtle pulsating effect
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Very subtle pulsating animation (0.95 to 1.05)
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Start data loading immediately
    _startDataLoading();
  }
  
  void _startDataLoading() async {
    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        // No connectivity, retry after delay
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            _startDataLoading();
          }
        });
        return;
      }
      
      // Try to load data
      await preloadData();
      
      // Navigate immediately when data is loaded
      if (mounted && isDataPreloaded) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    } catch (e) {
      print('Data loading error: $e');
      
      // Retry after delay
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _startDataLoading();
        }
      });
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
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: _animation.value,
              child: SvgPicture.asset(
                logoPath,
                width: 250,
                height: 150,
                fit: BoxFit.contain,
              ),
            );
          },
        ),
      ),
    );
  }
} 