import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/repositories/practice_history_repository.dart
//
// Stores AI practice sessions with band scores for the progress chart.
// ─────────────────────────────────────────────────────────────────────────────

class PracticeSession {
  final int cardId;
  final String topic;
  final String category;
  final double overallBand;
  final double fluencyBand;
  final double lexicalBand;
  final double grammarBand;
  final double pronunciationBand;
  final String transcript;
  final int durationSecs;
  final DateTime dateTime;

  const PracticeSession({
    required this.cardId,
    required this.topic,
    required this.category,
    required this.overallBand,
    required this.fluencyBand,
    required this.lexicalBand,
    required this.grammarBand,
    required this.pronunciationBand,
    required this.transcript,
    required this.durationSecs,
    required this.dateTime,
  });

  factory PracticeSession.fromJson(Map<String, dynamic> json) =>
      PracticeSession(
        cardId: json['cardId'] as int,
        topic: json['topic'] as String,
        category: json['category'] as String,
        overallBand: (json['overallBand'] as num).toDouble(),
        fluencyBand: (json['fluencyBand'] as num).toDouble(),
        lexicalBand: (json['lexicalBand'] as num).toDouble(),
        grammarBand: (json['grammarBand'] as num).toDouble(),
        pronunciationBand: (json['pronunciationBand'] as num).toDouble(),
        transcript: json['transcript'] as String,
        durationSecs: json['durationSecs'] as int,
        dateTime: DateTime.parse(json['dateTime'] as String),
      );

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'topic': topic,
        'category': category,
        'overallBand': overallBand,
        'fluencyBand': fluencyBand,
        'lexicalBand': lexicalBand,
        'grammarBand': grammarBand,
        'pronunciationBand': pronunciationBand,
        'transcript': transcript,
        'durationSecs': durationSecs,
        'dateTime': dateTime.toIso8601String(),
      };

  static PracticeSession fromFeedback({
    required int cardId,
    required String topic,
    required String category,
    required AiFeedback feedback,
    required String transcript,
    required int durationSecs,
  }) =>
      PracticeSession(
        cardId: cardId,
        topic: topic,
        category: category,
        overallBand: feedback.overallBand,
        fluencyBand: feedback.fluencyBand,
        lexicalBand: feedback.lexicalBand,
        grammarBand: feedback.grammarBand,
        pronunciationBand: feedback.pronunciationBand,
        transcript: transcript,
        durationSecs: durationSecs,
        dateTime: DateTime.now(),
      );
}

class PracticeHistoryRepository {
  static const String _key = 'ai_practice_history';

  static List<PracticeSession> getAll() {
    return _getAllSync();
  }

  static List<PracticeSession> _getAllSync() {
    // Access SharedPreferences synchronously through the stored instance
    final raw = _prefs?.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try {
            return PracticeSession.fromJson(
                json.decode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<PracticeSession>()
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // newest first
  }

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> addSession(PracticeSession session) async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getStringList(_key) ?? [];
    raw.add(json.encode(session.toJson()));
    // Keep max 100 sessions to avoid storage bloat
    if (raw.length > 100) raw.removeAt(0);
    await _prefs!.setStringList(_key, raw);
  }

  static int get sessionCount => _getAllSync().length;

  static double get averageBand {
    final all = _getAllSync();
    if (all.isEmpty) return 0;
    return all.map((s) => s.overallBand).reduce((a, b) => a + b) / all.length;
  }

  static double get highestBand {
    final all = _getAllSync();
    if (all.isEmpty) return 0;
    return all.map((s) => s.overallBand).reduce((a, b) => a > b ? a : b);
  }

  static Future<void> clearAll() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(_key, []);
  }
}
