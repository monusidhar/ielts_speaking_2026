import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── NEW: import prefs ─────────────────────────────────────────────────────────
import 'data/repositories/prefs_repository.dart';
import 'data/services/ad_service.dart';
import 'data/services/billing_service.dart';

// ─── Screen Imports ───────────────────────────────────────────────────────────
import 'screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/cue_cards/cue_cards_list_screen.dart';
import 'screens/cue_cards/cue_card_detail_screen.dart';
import 'screens/random_practice/random_practice_screen.dart';
import 'screens/bookmarks/bookmark_screen.dart';
import 'screens/vocabulary/vocabulary_screen.dart';
import 'screens/premium/premium_screen.dart';
import 'screens/privacy/privacy_screen.dart';
import 'screens/about/about_screen.dart';
import 'screens/practice/ai_practice_screen.dart';
import 'screens/practice/ai_feedback_screen.dart';
import 'screens/practice/practice_history_screen.dart';
import 'data/repositories/practice_history_repository.dart';
import 'data/repositories/cue_card_repository.dart';
import 'data/services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // ── Init SharedPreferences ────────────────────────────────────────────────
  await PrefsRepository.init();

  // ── Init AdMob ────────────────────────────────────────────────────────────
  await AdService.init();

  // ── Init Practice History ────────────────────────────────────────────────
  await PracticeHistoryRepository.init();

  // ── Init Billing (₹199 remove ads) ───────────────────────────────────────
  try {
    await BillingService.init();
  } catch (e) {
    debugPrint('Billing init failed (non-fatal): $e');
  }

  runApp(const IELTSSpeakingApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────────────────────
class IELTSSpeakingApp extends StatefulWidget {
  const IELTSSpeakingApp({super.key});

  // ── NEW: global handle so any screen can toggle theme ─────────────────────
  static _IELTSSpeakingAppState? _instance;
  static void toggleTheme(bool isDark) => _instance?._setTheme(isDark);

  @override
  State<IELTSSpeakingApp> createState() => _IELTSSpeakingAppState();
}

class _IELTSSpeakingAppState extends State<IELTSSpeakingApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    IELTSSpeakingApp._instance = this;
    // ── NEW: load saved dark mode preference ──────────────────────────────
    _isDarkMode = PrefsRepository.isDarkMode();
  }

  // ── NEW: saves to SharedPreferences every time theme changes ─────────────
  void _setTheme(bool isDark) {
    setState(() => _isDarkMode = isDark);
    PrefsRepository.setDarkMode(isDark);
  }

  // kept for backward compat if any screen calls this directly
  void toggleTheme(bool isDark) => _setTheme(isDark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IELTS Speaking 2026',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [homeRouteObserver], // ← makes Home refresh on back

      // ── Light Theme ─────────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
          primary: const Color(0xFF1565C0),
          secondary: const Color(0xFF0288D1),
          surface: const Color(0xFFF5F7FA),
          onPrimary: Colors.white,
          onSurface: const Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E)),
          titleLarge: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E)),
          titleMedium: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E)),
          bodyLarge:
              TextStyle(fontSize: 15, color: Color(0xFF333355), height: 1.6),
          bodyMedium:
              TextStyle(fontSize: 13, color: Color(0xFF555577), height: 1.5),
          labelSmall: TextStyle(
              fontSize: 11, color: Color(0xFF888899), letterSpacing: 0.8),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFE3F2FD),
          labelStyle: const TextStyle(
              color: Color(0xFF1565C0),
              fontSize: 12,
              fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        ),
        dividerTheme:
            const DividerThemeData(color: Color(0xFFEEEEF5), thickness: 1),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1565C0),
          unselectedItemColor: Color(0xFFAAAAAA),
          selectedLabelStyle:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11),
          elevation: 8,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: CircleBorder(),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // ── Dark Theme ──────────────────────────────────────────────────────
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DB6FF),
          brightness: Brightness.dark,
          primary: const Color(0xFF4DB6FF),
          secondary: const Color(0xFF29B6F6),
          surface: const Color(0xFF0F1B2D),
          onPrimary: const Color(0xFF0F1B2D),
          onSurface: const Color(0xFFE8EAF0),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1B2D),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1B2D),
          foregroundColor: Color(0xFFE8EAF0),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFE8EAF0),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: const Color(0xFF1A2E4A),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4DB6FF),
            foregroundColor: const Color(0xFF0F1B2D),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE8EAF0)),
          titleLarge: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE8EAF0)),
          titleMedium: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE8EAF0)),
          bodyLarge:
              TextStyle(fontSize: 15, color: Color(0xFFCDD5E0), height: 1.6),
          bodyMedium:
              TextStyle(fontSize: 13, color: Color(0xFF8899AA), height: 1.5),
          labelSmall: TextStyle(
              fontSize: 11, color: Color(0xFF557799), letterSpacing: 0.8),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF1A3A55),
          labelStyle: const TextStyle(
              color: Color(0xFF4DB6FF),
              fontSize: 12,
              fontWeight: FontWeight.w500),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A2E4A),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4DB6FF), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: Color(0xFF446688), fontSize: 14),
        ),
        dividerTheme:
            const DividerThemeData(color: Color(0xFF1A2E4A), thickness: 1),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0D1E30),
          selectedItemColor: Color(0xFF4DB6FF),
          unselectedItemColor: Color(0xFF446688),
          selectedLabelStyle:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11),
          elevation: 8,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF4DB6FF),
          foregroundColor: Color(0xFF0F1B2D),
          elevation: 4,
          shape: CircleBorder(),
        ),
      ),

      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // ── Routes ───────────────────────────────────────────────────────────
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (ctx) => const SplashScreen(),
        AppRoutes.home: (ctx) => const HomeScreen(),
        AppRoutes.cueCardsList: (ctx) => const CueCardsListScreen(),
        AppRoutes.randomPractice: (ctx) => const RandomPracticeScreen(),
        AppRoutes.bookmarks: (ctx) => const BookmarkScreen(),
        AppRoutes.vocabulary: (ctx) => const VocabularyScreen(),
        AppRoutes.premium: (ctx) => const PremiumScreen(),
        AppRoutes.privacy: (ctx) => const PrivacyScreen(),
        AppRoutes.about: (ctx) => const AboutScreen(),
        AppRoutes.aiPractice: (ctx) => const AiPracticeScreen(),
        AppRoutes.practiceHistory: (ctx) => const PracticeHistoryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.cueCardDetail) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (ctx) => CueCardDetailScreen(
              cardId: args['cardId'] as int,
            ),
          );
        }
        if (settings.name == AppRoutes.aiFeedback) {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (ctx) => AiFeedbackScreen(
              feedback: args['feedback'] as AiFeedback,
              card: args['card'] as CueCard,
              transcript: args['transcript'] as String,
            ),
          );
        }
        return null;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ROUTES
// ─────────────────────────────────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();
  static const String splash = '/';
  static const String home = '/home';
  static const String cueCardsList = '/cue-cards';
  static const String cueCardDetail = '/cue-card-detail';
  static const String randomPractice = '/random-practice';
  static const String bookmarks = '/bookmarks';
  static const String vocabulary = '/vocabulary';
  static const String premium = '/premium';
  static const String privacy = '/privacy';
  static const String about = '/about';
  static const String aiPractice = '/ai-practice';
  static const String aiFeedback = '/ai-feedback';
  static const String practiceHistory = '/practice-history';
}

// ─────────────────────────────────────────────────────────────────────────────
// APP COLORS
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color primaryBlueDark = Color(0xFF4DB6FF);
  static const Color accentBlue = Color(0xFF0288D1);
  static const Color accentGold = Color(0xFFFFB300);
  static const Color bgLight = Color(0xFFF5F7FA);
  static const Color bgDark = Color(0xFF0F1B2D);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1A2E4A);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textPrimaryDark = Color(0xFFE8EAF0);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFC62828);
  static const Color band7 = Color(0xFF1976D2);
  static const Color band8 = Color(0xFF6A1B9A);
}
