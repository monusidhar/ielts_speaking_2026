import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../data/services/ad_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/widgets/banner_ad_widget.dart
//
// Drop this widget anywhere you want a banner ad.
// It automatically hides itself if user is premium.
//
// USAGE:
//   const BannerAdWidget()   ← standard 320×50 banner
//   const BannerAdWidget(size: AdSize.largeBanner)  ← 320×100
// ─────────────────────────────────────────────────────────────────────────────

class BannerAdWidget extends StatefulWidget {
  final AdSize size;
  const BannerAdWidget({super.key, this.size = AdSize.banner});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    final banner = AdService.createBanner(
      size: widget.size,
      onLoaded: () {
        if (mounted) setState(() => _loaded = true);
      },
      onFailed: () {
        if (mounted) setState(() => _loaded = false);
      },
    );

    if (banner == null) return; // premium user — AdService returned null

    banner.load();
    _banner = banner;
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ad not loaded — show nothing (zero height)
    if (!_loaded || _banner == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: _banner!.size.width.toDouble(),
      height: _banner!.size.height.toDouble(),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1E30) : const Color(0xFFF5F7FA),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1A2E4A) : const Color(0xFFDDDDEE),
            width: 1,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: AdWidget(ad: _banner!),
    );
  }
}
