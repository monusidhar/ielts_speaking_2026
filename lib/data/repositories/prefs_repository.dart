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

  // ── Mock Interview keys ────────────────────────────────────────────────
  static const _kMockFreeUsed = 'mock_free_completed'; // bool
  static const _kMockDailyCount = 'mock_daily_count'; // int
  static const _kMockDailyDate = 'mock_daily_date'; // String (yyyy-MM-dd)

  // ── Daily AI Question keys ─────────────────────────────────────────────
  static const _kDailyQuestionText = 'daily_question_text'; // String
  static const _kDailyQuestionPart = 'daily_question_part'; // String (Part 1/3)
  static const _kDailyQuestionDate =
      'daily_question_date'; // String (yyyy-MM-dd)

  // ── Daily Streak keys ──────────────────────────────────────────────────
  static const _kStreakCount = 'streak_count'; // int
  static const _kStreakLastDate = 'streak_last_date'; // String (yyyy-MM-dd)

  // ── Target Band & Exam Countdown ───────────────────────────────────────
  static const _kTargetBand = 'target_band'; // double (e.g. 7.0)
  static const _kExamDate = 'exam_date'; // String (yyyy-MM-dd)

  // ── In-App Review & Notifications ──────────────────────────────────────
  static const _kReviewPrompted = 'review_prompted'; // bool
  static const _kTotalAiSessions = 'total_ai_sessions'; // int
  static const _kNotificationsEnabled = 'notifications_enabled'; // bool

  // ── Part 1 & 3 Practice Tracking ───────────────────────────────────────
  static const _kPart1Practiced = 'part1_practiced_ids'; // List<String>
  static const _kPart3Practiced = 'part3_practiced_ids'; // List<String>

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

  // ─────────────────────────────────────────────────────────────────────────
  // MOCK INTERVIEW LIMITS
  // Free: 1 lifetime trial  •  Premium: 5/day
  // ─────────────────────────────────────────────────────────────────────────

  static const int mockDailyLimitPremium = 5;

  /// Whether the free user has already used their 1 lifetime mock interview
  static bool hasMockFreeBeenUsed() => _p.getBool(_kMockFreeUsed) ?? false;

  /// Whether user can start another mock interview
  static bool canDoMockInterview() {
    if (isPremium()) return getMockDailyCount() < mockDailyLimitPremium;
    return !hasMockFreeBeenUsed();
  }

  /// How many mock interviews done today (premium only counter)
  static int getMockDailyCount() {
    final savedDate = _p.getString(_kMockDailyDate) ?? '';
    if (savedDate != _todayStr()) return 0;
    return _p.getInt(_kMockDailyCount) ?? 0;
  }

  /// Remaining mock interviews
  static int getMockRemaining() {
    if (isPremium()) {
      return (mockDailyLimitPremium - getMockDailyCount())
          .clamp(0, mockDailyLimitPremium);
    }
    return hasMockFreeBeenUsed() ? 0 : 1;
  }

  /// Call after a mock interview completes
  static Future<void> incrementMockCount() async {
    if (!isPremium()) {
      await _p.setBool(_kMockFreeUsed, true);
      return;
    }
    final today = _todayStr();
    final savedDate = _p.getString(_kMockDailyDate) ?? '';
    if (savedDate != today) {
      await _p.setString(_kMockDailyDate, today);
      await _p.setInt(_kMockDailyCount, 1);
    } else {
      final count = _p.getInt(_kMockDailyCount) ?? 0;
      await _p.setInt(_kMockDailyCount, count + 1);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAILY AI QUESTION (cached, one API call/day)
  // ─────────────────────────────────────────────────────────────────────────

  /// Get cached daily question (null if none for today)
  static String? getDailyQuestion() {
    final savedDate = _p.getString(_kDailyQuestionDate) ?? '';
    if (savedDate != _todayStr()) return null;
    return _p.getString(_kDailyQuestionText);
  }

  /// Get the part type (e.g. "Part 1" or "Part 3")
  static String getDailyQuestionPart() {
    return _p.getString(_kDailyQuestionPart) ?? 'Part 1';
  }

  /// Save today's daily question
  static Future<void> saveDailyQuestion(String question, String part) async {
    await _p.setString(_kDailyQuestionDate, _todayStr());
    await _p.setString(_kDailyQuestionText, question);
    await _p.setString(_kDailyQuestionPart, part);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DAILY STREAK
  // ─────────────────────────────────────────────────────────────────────────

  /// Get current streak count (checks if streak is still valid)
  static int getStreakCount() {
    final lastDate = _p.getString(_kStreakLastDate) ?? '';
    final today = _todayStr();
    if (lastDate == today) return _p.getInt(_kStreakCount) ?? 0;

    // Check if yesterday — streak still alive but not yet recorded today
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (lastDate == yStr) return _p.getInt(_kStreakCount) ?? 0;

    // More than 1 day gap — streak broken
    return 0;
  }

  /// Record today's practice (call after any practice session)
  static Future<void> recordStreakToday() async {
    final today = _todayStr();
    final lastDate = _p.getString(_kStreakLastDate) ?? '';
    if (lastDate == today) return; // Already recorded today

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    int newStreak;
    if (lastDate == yStr) {
      // Consecutive day — increment
      newStreak = (_p.getInt(_kStreakCount) ?? 0) + 1;
    } else {
      // Gap or first ever — start fresh
      newStreak = 1;
    }
    await _p.setString(_kStreakLastDate, today);
    await _p.setInt(_kStreakCount, newStreak);
  }

  /// Whether today's practice has been done
  static bool hasPracticedToday() {
    return _p.getString(_kStreakLastDate) == _todayStr();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TARGET BAND & EXAM COUNTDOWN
  // ─────────────────────────────────────────────────────────────────────────

  static double? getTargetBand() {
    final v = _p.getDouble(_kTargetBand);
    return v;
  }

  static Future<void> setTargetBand(double band) async {
    await _p.setDouble(_kTargetBand, band);
  }

  static String? getExamDate() => _p.getString(_kExamDate);

  static Future<void> setExamDate(String dateStr) async {
    await _p.setString(_kExamDate, dateStr);
  }

  static Future<void> clearExamDate() async {
    await _p.remove(_kExamDate);
  }

  /// Days remaining until exam (null if no date set)
  static int? getDaysUntilExam() {
    final dateStr = getExamDate();
    if (dateStr == null) return null;
    try {
      final exam = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return exam.difference(today).inDays;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IN-APP REVIEW TRACKING
  // ─────────────────────────────────────────────────────────────────────────

  static bool hasBeenReviewPrompted() => _p.getBool(_kReviewPrompted) ?? false;

  static Future<void> setReviewPrompted() async {
    await _p.setBool(_kReviewPrompted, true);
  }

  /// Total AI sessions ever (for triggering review prompt)
  static int getTotalAiSessions() => _p.getInt(_kTotalAiSessions) ?? 0;

  static Future<void> incrementTotalAiSessions() async {
    final count = (_p.getInt(_kTotalAiSessions) ?? 0) + 1;
    await _p.setInt(_kTotalAiSessions, count);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATION PREFERENCE
  // ─────────────────────────────────────────────────────────────────────────

  static bool isNotificationsEnabled() =>
      _p.getBool(_kNotificationsEnabled) ?? true; // default ON

  static Future<void> setNotificationsEnabled(bool value) async {
    await _p.setBool(_kNotificationsEnabled, value);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PART 1 & PART 3 PRACTICE TRACKING
  // ─────────────────────────────────────────────────────────────────────────

  static Set<int> getPart1PracticedIds() {
    final raw = _p.getStringList(_kPart1Practiced) ?? [];
    return raw
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id != -1)
        .toSet();
  }

  static Future<void> markPart1Practiced(int topicId) async {
    final ids = getPart1PracticedIds()..add(topicId);
    await _p.setStringList(
        _kPart1Practiced, ids.map((e) => e.toString()).toList());
  }

  static Set<int> getPart3PracticedIds() {
    final raw = _p.getStringList(_kPart3Practiced) ?? [];
    return raw
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id != -1)
        .toSet();
  }

  static Future<void> markPart3Practiced(int topicId) async {
    final ids = getPart3PracticedIds()..add(topicId);
    await _p.setStringList(
        _kPart3Practiced, ids.map((e) => e.toString()).toList());
  }
}
