import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../repositories/prefs_repository.dart';
import '../app_secrets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/services/ad_service.dart
//
// HOW TO USE:
//   1. Call AdService.init() in main() after PrefsRepository.init()
//   2. Use AdService.createBanner() to get a banner ad widget
//   3. Call AdService.showInterstitial() after practice finishes
//   4. All ads are hidden automatically when user is premium
// ─────────────────────────────────────────────────────────────────────────────

class AdService {
  AdService._();

  // ── Replace these with your real AdMob IDs from AdMob console ────────────
  // Get them at: https://admob.google.com → Apps → Ad units
  static const String _bannerIdReal = AppSecrets.admobBannerId;
  static const String _interstitialIdReal = AppSecrets.admobInterstitialId;
  static const String _rewardedInterstitialIdReal =
      AppSecrets.admobRewardedInterstitialId;

  // ── Test IDs — safe to use during development ─────────────────────────────
  // These show real test ads, no policy violations
  static const String _bannerIdTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String _interstitialIdTest =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _rewardedInterstitialIdTest =
      'ca-app-pub-3940256099942544/5354046379';

  // Switch to real IDs only when publishing to Play Store
  static bool get _isRelease => kReleaseMode;
  static String get _bannerId => _isRelease ? _bannerIdReal : _bannerIdTest;
  static String get _interstitialId =>
      _isRelease ? _interstitialIdReal : _interstitialIdTest;
  static String get _rewardedInterstitialId =>
      _isRelease ? _rewardedInterstitialIdReal : _rewardedInterstitialIdTest;

  // ── State ──────────────────────────────────────────────────────────────────
  static bool _initialized = false;
  static InterstitialAd? _interstitialAd;
  static bool _interstitialReady = false;
  static int _interstitialShowCount = 0;
  static RewardedInterstitialAd? _rewardedInterstitialAd;
  static bool _rewardedInterstitialReady = false;

  // Show interstitial every N practices (not every single time — too aggressive)
  static const int _interstitialFrequency = 3;

  // ── Init — call once in main() ─────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial(); // pre-load ready for first use
    _loadRewardedInterstitial(); // pre-load video ad for AI practice
  }

  // ── Is premium? — skip all ads ─────────────────────────────────────────────
  static bool get _isPremium => PrefsRepository.isPremium();

  // ─────────────────────────────────────────────────────────────────────────
  // BANNER ADS
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a fresh BannerAd. Call .load() then use AdWidget(ad: banner).
  /// Caller is responsible for calling banner.dispose() when done.
  static BannerAd? createBanner({
    AdSize size = AdSize.banner,
    void Function()? onLoaded,
    void Function()? onFailed,
  }) {
    if (_isPremium) return null; // no ads for premium users

    return BannerAd(
      adUnitId: _bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (_, err) {
          debugPrint('Banner failed: $err');
          onFailed?.call();
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERSTITIAL ADS
  // ─────────────────────────────────────────────────────────────────────────

  static void _loadInterstitial() {
    if (_isPremium) return;

    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _interstitialReady = false;
              _loadInterstitial(); // pre-load next one immediately
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _interstitialAd = null;
              _interstitialReady = false;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial failed to load: $err');
          _interstitialReady = false;
          // Retry after 60 seconds
          Future.delayed(const Duration(seconds: 60), _loadInterstitial);
        },
      ),
    );
  }

  /// Call this after a practice session completes.
  /// Shows interstitial every [_interstitialFrequency] sessions.
  static Future<void> showInterstitialAfterPractice() async {
    if (_isPremium) return;

    _interstitialShowCount++;
    if (_interstitialShowCount % _interstitialFrequency != 0) return;

    if (_interstitialReady && _interstitialAd != null) {
      await _interstitialAd!.show();
    }
  }

  /// Force show interstitial (e.g. on random card skip after N skips)
  static Future<void> showInterstitial() async {
    if (_isPremium) return;
    if (_interstitialReady && _interstitialAd != null) {
      await _interstitialAd!.show();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REWARDED INTERSTITIAL ADS (video ad after AI practice)
  // ─────────────────────────────────────────────────────────────────────────

  static void _loadRewardedInterstitial() {
    if (_isPremium) return;

    RewardedInterstitialAd.load(
      adUnitId: _rewardedInterstitialId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _rewardedInterstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedInterstitialAd = null;
              _rewardedInterstitialReady = false;
              _loadRewardedInterstitial(); // pre-load next one
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _rewardedInterstitialAd = null;
              _rewardedInterstitialReady = false;
              _loadRewardedInterstitial();
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('Rewarded interstitial failed to load: $err');
          _rewardedInterstitialReady = false;
          Future.delayed(
              const Duration(seconds: 60), _loadRewardedInterstitial);
        },
      ),
    );
  }

  /// Show video ad after AI practice. Shows every time for free users.
  /// Falls back to regular interstitial if video ad isn't ready.
  static Future<void> showVideoAdAfterAiPractice() async {
    if (_isPremium) return;

    if (_rewardedInterstitialReady && _rewardedInterstitialAd != null) {
      await _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        },
      );
    } else {
      // Fallback: show regular interstitial if video ad not loaded
      await showInterstitial();
    }
  }

  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedInterstitialAd?.dispose();
  }
}
