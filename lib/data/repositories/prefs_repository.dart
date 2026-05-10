import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/repositories/prefs_repository.dart
//
// Central place for ALL SharedPreferences read/write.
// Every screen imports this — nothing talks to SharedPreferences directly.
// ─────────────────────────────────────────────────────────────────────────────

class PrefsRepository {
  // ── Keys ───────────────────────────────────────────────────────────────────
  static const _kBookmarks = 'bookmarked_card_ids'; // List<String> of int IDs
  static const _kPracticed = 'practiced_card_ids'; // List<String> of int IDs
  static const _kPracticedTotal =
      'practiced_total_count'; // int — legacy counter
  static const _kIsPremium = 'is_premium'; // bool
  static const _kIsDarkMode = 'is_dark_mode'; // bool
  static const _kAiDailyCount = 'ai_daily_count'; // int
  static const _kAiDailyDate = 'ai_daily_date'; // String (yyyy-MM-dd)

  // ── Singleton ──────────────────────────────────────────────────────────────
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get _p {
    assert(_prefs != null, 'Call PrefsRepository.init() before using it.');
    return _prefs!;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BOOKMARKS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get all bookmarked card IDs
  static Set<int> getBookmarkedIds() {
    final raw = _p.getStringList(_kBookmarks) ?? [];
    return raw
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id != -1)
        .toSet();
  }

  /// Returns true if card is bookmarked
  static bool isBookmarked(int cardId) => getBookmarkedIds().contains(cardId);

  /// Toggle bookmark — returns true if now bookmarked, false if removed
  static Future<bool> toggleBookmark(int cardId) async {
    final ids = getBookmarkedIds();
    if (ids.contains(cardId)) {
      ids.remove(cardId);
      await _p.setStringList(
          _kBookmarks, ids.map((e) => e.toString()).toList());
      return false;
    } else {
      ids.add(cardId);
      await _p.setStringList(
          _kBookmarks, ids.map((e) => e.toString()).toList());
      return true;
    }
  }

  /// Remove a bookmark directly
  static Future<void> removeBookmark(int cardId) async {
    final ids = getBookmarkedIds()..remove(cardId);
    await _p.setStringList(_kBookmarks, ids.map((e) => e.toString()).toList());
  }

  /// Clear all bookmarks
  static Future<void> clearAllBookmarks() async {
    await _p.setStringList(_kBookmarks, []);
  }

  /// Count of bookmarked cards
  static int getBookmarkedCount() => getBookmarkedIds().length;

  // ─────────────────────────────────────────────────────────────────────────
  // PRACTICED CARDS
  // ─────────────────────────────────────────────────────────────────────────

  /// Get all practiced card IDs
  static Set<int> getPracticedIds() {
    final raw = _p.getStringList(_kPracticed) ?? [];
    return raw
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id != -1)
        .toSet();
  }

  /// Mark a card as practiced
  static Future<void> markPracticed(int cardId) async {
    final ids = getPracticedIds()..add(cardId);
    await _p.setStringList(_kPracticed, ids.map((e) => e.toString()).toList());
    // Also increment the raw total counter
    final count = _p.getInt(_kPracticedTotal) ?? 0;
    await _p.setInt(_kPracticedTotal, count + 1);
  }

  /// Total number of practice sessions (includes repeats)
  static int getPracticedTotal() => _p.getInt(_kPracticedTotal) ?? 0;

  /// Count of unique cards practiced
  static int getPracticedUniqueCount() => getPracticedIds().length;

  /// Reset practiced history
  static Future<void> clearPracticed() async {
    await _p.setStringList(_kPracticed, []);
    await _p.setInt(_kPracticedTotal, 0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PREMIUM
  // ─────────────────────────────────────────────────────────────────────────

  static bool isPremium() => _p.getBool(_kIsPremium) ?? false;

  static Future<void> setPremium(bool value) async {
    await _p.setBool(_kIsPremium, value);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DARK MODE
  // ─────────────────────────────────────────────────────────────────────────

  static bool isDarkMode() => _p.getBool(_kIsDarkMode) ?? false;

  static Future<void> setDarkMode(bool value) async {
    await _p.setBool(_kIsDarkMode, value);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUMMARY STATS (used by Home Screen)
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, int> getStats() => {
        'practiced': getPracticedUniqueCount(),
        'bookmarked': getBookmarkedCount(),
      };

  // ─────────────────────────────────────────────────────────────────────────
  // DEBUG — clear everything (use in dev only)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> clearAll() async => await _p.clear();

  // ─────────────────────────────────────────────────────────────────────────
  // AI DAILY LIMIT (controls API cost)
  // ─────────────────────────────────────────────────────────────────────────

  static const int aiDailyLimitFree = 5;
  static const int aiDailyLimitPremium = 15;

  /// Current user's daily limit based on premium status
  static int get aiDailyLimit =>
      isPremium() ? aiDailyLimitPremium : aiDailyLimitFree;

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// How many AI practices the user has done today
  static int getAiDailyCount() {
    final savedDate = _p.getString(_kAiDailyDate) ?? '';
    if (savedDate != _todayStr()) return 0; // new day → reset
    return _p.getInt(_kAiDailyCount) ?? 0;
  }

  /// How many AI practices remaining today
  static int getAiRemaining() =>
      (aiDailyLimit - getAiDailyCount()).clamp(0, aiDailyLimit);

  /// Whether user can do another AI practice today
  static bool canUseAi() => getAiDailyCount() < aiDailyLimit;

  /// Increment today's AI practice count
  static Future<void> incrementAiDailyCount() async {
    final today = _todayStr();
    final savedDate = _p.getString(_kAiDailyDate) ?? '';
    if (savedDate != today) {
      // New day — reset counter
      await _p.setString(_kAiDailyDate, today);
      await _p.setInt(_kAiDailyCount, 1);
    } else {
      final count = _p.getInt(_kAiDailyCount) ?? 0;
      await _p.setInt(_kAiDailyCount, count + 1);
    }
  }
}
