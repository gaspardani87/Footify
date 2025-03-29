import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/scheduler.dart';
import 'main.dart';
import 'dashboard.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  bool _dataLoaded = false;
  bool _showCircle = false;
  bool _circleFullyGrown = false;
  bool _circleFadedOut = false;

  // Főképernyő előre betöltve
  Widget? _preloadedMainScreen;

  late AnimationController _logoController;
  late AnimationController _circleGrowController;
  late AnimationController _circleFadeController;

  late Animation<double> _circleScaleAnimation;
  late Animation<double> _circleFadeAnimation;

  // Segédfüggvény a scheduler.yield() vagy setTimeout() használatához
  Future<void> _yieldToMain() async {
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      // Ellenőrizzük, hogy van-e Scheduler ÉS nem idle fázisban van
      await SchedulerBinding.instance.endOfFrame; // Korrektebb várakozás
    } else {
      // Tartalék megoldás: setTimeout 0-val
      await Future.delayed(Duration.zero);
    }
  }

  @override
  void initState() {
    super.initState();

    // Logo pulzálás animáció - EGYELŐRE NEM KAPCSOLJUK KI, DE KÉSŐBB LEHET
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _logoController.repeat(reverse: true); // Ezt figyeljük, ha kell, kikapcsoljuk

    // Kör növekedés animáció
    _circleGrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Kör eltűnés animáció
    _circleFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Kör méretének változása
    _circleScaleAnimation = CurvedAnimation(
      parent: _circleGrowController,
      curve: Curves.easeInOutCubic,
    );

    // Kör eltűnésének animációja
    _circleFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _circleFadeController,
        curve: Curves.easeOut,
      ),
    );

    // Figyeljük a kör növekedését
    _circleGrowController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _circleFullyGrown = true;
        });
        // Indítjuk a fade-out animációt
        _circleFadeController.forward();
      }
    });

    // Figyeljük a kör elhalványulását
    _circleFadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _circleFadedOut = true;
        });
      }
    });

    // Adatok betöltése - ITT HASZNÁLJUK A YIELD-et
    _startDataLoading();
  }

  // Adatok betöltése (módosított)
  Future<void> _startDataLoading() async {
    try {
      debugPrint('AnimatedSplashScreen: Starting data loading');
      
      // Track start time to ensure minimum splash screen duration
      final startTime = DateTime.now();
      
      // Előre betöltjük a főképernyőt
      _preloadedMainScreen = const DashboardPage();
      debugPrint('AnimatedSplashScreen: DashboardPage preloaded');

      // Adatok betöltése (aszinkron módon, yield-del)
      if (!isDataPreloaded) {
        debugPrint('AnimatedSplashScreen: Calling preloadData()');
        await preloadData();
        await _yieldToMain(); // YIELD a fő szálnak
        debugPrint('AnimatedSplashScreen: preloadData() completed');
      } else {
        debugPrint('AnimatedSplashScreen: Data already preloaded');
      }
      
      // Wait for the dashboard to signal it has loaded its data
      debugPrint('AnimatedSplashScreen: Waiting for DashboardPage.dataLoaded');
      
      // CRITICAL: Always wait for DashboardPage.dataLoaded before proceeding
      try {
        // Wait with a more generous timeout for dashboard data loading
        // This is the critical path to ensure we don't show the dashboard until it's ready
        bool dataLoadResult = await DashboardPage.dataLoaded.timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            debugPrint('AnimatedSplashScreen: TIMEOUT waiting for dashboard data');
            return true; // Continue anyway after timeout
          },
        );
        debugPrint('AnimatedSplashScreen: DashboardPage.dataLoaded completed with result: $dataLoadResult');
      } catch (e) {
        debugPrint('AnimatedSplashScreen: Error waiting for dashboard data: $e');
      }

      // Ensure minimum display time for the splash screen (0.8 seconds)
      final elapsedMillis = DateTime.now().difference(startTime).inMilliseconds;
      const minSplashTimeMillis = 800; // Reduced from 1500 to 800ms for faster startup
      
      if (elapsedMillis < minSplashTimeMillis) {
        final remainingTime = minSplashTimeMillis - elapsedMillis;
        debugPrint('AnimatedSplashScreen: Waiting additional ${remainingTime}ms to ensure minimum splash time');
        await Future.delayed(Duration(milliseconds: remainingTime));
      }

      // Amikor az adatok betöltődtek:
      if (mounted) {
        debugPrint('AnimatedSplashScreen: Setting state to start circle animation');
        setState(() {
          _dataLoaded = true;
          _showCircle = true;
        });

        // Indítjuk a kör növekedését
        _circleGrowController.forward();
        debugPrint('AnimatedSplashScreen: Circle grow animation started');
      } else {
        debugPrint('AnimatedSplashScreen: Not mounted anymore');
      }
    } catch (e) {
      debugPrint('Error loading data in AnimatedSplashScreen: $e');
      if (mounted && !_dataLoaded) {
        debugPrint('AnimatedSplashScreen: Retrying data loading after error');
        Future.delayed(const Duration(seconds: 1), _startDataLoading);
      }
    }
  }

  // Minden meccs és logó betöltése (yield-del)
  Future<void> _preloadAllMatchesAndLogos() async {
    try {
      // Példa késleltetés, valós projektben ezt helyettesítsd a tényleges betöltéssel
      await Future.delayed(const Duration(seconds: 2));
      await _yieldToMain(); // YIELD a fő szálnak

      // Betöltünk egy képet példaként
      await precacheImage(const AssetImage('assets/images/Footify-Logo.png'), context);
      await _yieldToMain(); // YIELD a fő szálnak
    } catch (e) {
      print('Error preloading assets: $e');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _circleGrowController.dispose();
    _circleFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final initialCircleSize = size.width * 0.01;
    final screenDiagonal =
        math.sqrt(size.width * size.width + size.height * size.height);
    final maxCircleSize = screenDiagonal * 2.5;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
      body: Stack(
        children: [
          // Előre betöltött főképernyő
          if (_dataLoaded && _preloadedMainScreen != null)
            Positioned.fill(
              child: _preloadedMainScreen!,
            ),

          // Szürke háttér
          if (!_circleFullyGrown)
            Positioned.fill(
              child: Container(
                color: isDarkMode ? const Color(0xFF1D1D1D) : Colors.white,
              ),
            ),

          // Pulzáló logó
          if (!_circleFullyGrown)
            Center(
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  final scale = 1.0 + (_logoController.value * 0.08);
                  return Transform.scale(
                    scale: scale,
                    child: SvgPicture.asset(
                      isDarkMode
                          ? 'assets/images/footify_logo_optimized_dark.svg'
                          : 'assets/images/footify_logo_optimized_light.svg',
                      width: 250,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
            ),

          // Növekvő és halványuló kör
          if (_showCircle && !_circleFadedOut)
            Center(
              child: AnimatedBuilder(
                animation:
                    Listenable.merge([_circleGrowController, _circleFadeController]),
                builder: (context, child) {
                  final currentSize = initialCircleSize +
                      (maxCircleSize - initialCircleSize) *
                          _circleScaleAnimation.value;

                  final progress = _circleScaleAnimation.value;
                  final radiusPercent =
                      math.max(0.0, 1.0 - (progress * progress * progress));
                  final borderRadius = (currentSize / 2) * radiusPercent;

                  final opacity = _circleFadeAnimation.value;

                  return Opacity(
                    opacity: opacity,
                    child: Container(
                      width: currentSize,
                      height: currentSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE5AC),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
} 