import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../repositories/prefs_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/services/review_service.dart
//
// Triggers Play Store in-app review at the right moment.
// Uses in_app_review package (same package for iOS App Store reviews).
// ─────────────────────────────────────────────────────────────────────────────

class ReviewService {
  static final InAppReview _review = InAppReview.instance;

  /// Check if we should prompt for review and do it.
  /// Call after AI evaluation completes.
  /// Triggers only once, after 3+ AI sessions AND band >= 6.0
  static Future<void> maybeRequestReview(double bandScore) async {
    // Already prompted once — never ask again
    if (PrefsRepository.hasBeenReviewPrompted()) return;

    // Track total sessions
    await PrefsRepository.incrementTotalAiSessions();
    final totalSessions = PrefsRepository.getTotalAiSessions();

    // Conditions: at least 3 sessions AND got a decent score
    if (totalSessions >= 3 && bandScore >= 6.0) {
      try {
        final available = await _review.isAvailable();
        if (available) {
          await _review.requestReview();
          await PrefsRepository.setReviewPrompted();
        }
      } catch (e) {
        debugPrint('In-app review error (non-fatal): $e');
      }
    }
  }
}
