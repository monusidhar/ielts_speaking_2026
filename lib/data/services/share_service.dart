import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/services/share_service.dart
//
// Generates shareable text for band scores. Uses share_plus (already in deps).
// ─────────────────────────────────────────────────────────────────────────────

class ShareService {
  /// Share AI practice band score
  static Future<void> shareBandScore({
    required double overallBand,
    required String topic,
    required double fluency,
    required double lexical,
    required double grammar,
    required double pronunciation,
  }) async {
    final text = '🎯 I scored Band ${overallBand.toStringAsFixed(1)} '
        'on IELTS Speaking practice!\n\n'
        '📝 Topic: $topic\n'
        '🗣️ Fluency: ${fluency.toStringAsFixed(1)} '
        '| 📖 Lexical: ${lexical.toStringAsFixed(1)}\n'
        '✏️ Grammar: ${grammar.toStringAsFixed(1)} '
        '| 🔊 Pronunciation: ${pronunciation.toStringAsFixed(1)}\n\n'
        'Practicing with IELTS Speaking 2026 app! '
        'Download: https://play.google.com/store/apps/details?id=com.monusidhar.ielts_speaking_2026';

    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Share mock interview result
  static Future<void> shareMockResult({
    required double overallBand,
    required double part1Band,
    required double part2Band,
    required double part3Band,
  }) async {
    final text = '🏆 I completed a Full IELTS Mock Interview!\n\n'
        '📊 Overall Band: ${overallBand.toStringAsFixed(1)}\n'
        '  Part 1: ${part1Band.toStringAsFixed(1)} '
        '| Part 2: ${part2Band.toStringAsFixed(1)} '
        '| Part 3: ${part3Band.toStringAsFixed(1)}\n\n'
        'Practicing with IELTS Speaking 2026 app! '
        'Download: https://play.google.com/store/apps/details?id=com.monusidhar.ielts_speaking_2026';

    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Share daily question score
  static Future<void> shareDailyScore({
    required double overallBand,
    required String question,
    required String partType,
  }) async {
    final shortQ =
        question.length > 60 ? '${question.substring(0, 57)}...' : question;
    final text = '✨ I scored Band ${overallBand.toStringAsFixed(1)} '
        'on today\'s Daily AI Question!\n\n'
        '📝 $partType: $shortQ\n\n'
        'Practicing with IELTS Speaking 2026 app! '
        'Download: https://play.google.com/store/apps/details?id=com.monusidhar.ielts_speaking_2026';

    await SharePlus.instance.share(ShareParams(text: text));
  }
}
