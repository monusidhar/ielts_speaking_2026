import 'package:flutter/material.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/billing_service.dart';
import '../../data/services/notification_service.dart';
import '../../data/repositories/practice_history_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/splash/splash_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeIn = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _scaleIn = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _ctrl.forward();

    // Init heavy services in parallel WHILE splash animation plays,
    // then navigate to home once both the minimum splash time (1.5s)
    // and all inits are done.
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    final results = await Future.wait([
      // Minimum splash display time (animation needs ~1s)
      Future.delayed(const Duration(milliseconds: 1500)),
      // Heavy services run in parallel:
      AdService.init(),
      PracticeHistoryRepository.init(),
      BillingService.init().catchError((e) {
        debugPrint('Billing init failed (non-fatal): $e');
      }),
      NotificationService.init().catchError((e) {
        debugPrint('Notification init failed (non-fatal): $e');
      }),
    ]);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F1B2D),
              Color(0xFF1A2E4A),
              Color(0xFF0D2137),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Decorative rings ──────────────────────────────────────────
            _Ring(size: 320, opacity: 0.07),
            _Ring(size: 240, opacity: 0.11),
            _Ring(size: 165, opacity: 0.16),

            // ── Main content ──────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo circle
                    Container(
                      width: 114,
                      height: 114,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E6FA8),
                            Color(0xFF2D9DE0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2D9DE0).withOpacity(0.38),
                            blurRadius: 48,
                            spreadRadius: 6,
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'IE',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'SPEAKING',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              letterSpacing: 2.8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // App title
                    const Text(
                      'IELTS Speaking',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Edition badge
                    const Text(
                      '2026  EDITION',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4DB6FF),
                        letterSpacing: 5.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tagline
                    FadeTransition(
                      opacity: _taglineFade,
                      child: const Text(
                        '200+ Cue Cards  ·  Band 7–8 Answers',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white38,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Loading bar ───────────────────────────────────────────────
            Positioned(
              bottom: 80,
              child: FadeTransition(
                opacity: _taglineFade,
                child: const _LoadingBar(),
              ),
            ),

            // ── Disclaimer ────────────────────────────────────────────────
            Positioned(
              bottom: 28,
              child: FadeTransition(
                opacity: _taglineFade,
                child: const Text(
                  'Not affiliated with IELTS or British Council',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white24,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Decorative Ring Widget ───────────────────────────────────────────────────
class _Ring extends StatelessWidget {
  final double size;
  final double opacity;

  const _Ring({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF64B4FF).withOpacity(opacity),
          width: 1,
        ),
      ),
    );
  }
}

// ─── Animated Loading Bar ─────────────────────────────────────────────────────
class _LoadingBar extends StatefulWidget {
  const _LoadingBar();

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;
  late Animation<double> _barAnim;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _barAnim = CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut);
    _barCtrl.forward();
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _barAnim,
              builder: (context, _) {
                return LinearProgressIndicator(
                  value: _barAnim.value,
                  minHeight: 3,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4DB6FF),
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
