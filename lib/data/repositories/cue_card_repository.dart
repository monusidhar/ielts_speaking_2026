import 'dart:convert';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/repositories/cue_card_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
//
// pubspec.yaml — register the asset:
//   flutter:
//     assets:
//       - assets/data/cue_cards.json
// ─────────────────────────────────────────────────────────────────────────────

// ── Free tier limit ───────────────────────────────────────────────────────────
// Cards with ID <= kFreeCardLimit are accessible to free users.
// Cards with ID > kFreeCardLimit require premium.
const int kFreeCardLimit = 50;

// ── Models ────────────────────────────────────────────────────────────────────

class VocabWord {
  final String word;
  final String partOfSpeech;
  final String meaning;
  final String example;

  const VocabWord({
    required this.word,
    required this.partOfSpeech,
    required this.meaning,
    required this.example,
  });

  factory VocabWord.fromJson(Map<String, dynamic> json) => VocabWord(
        word:         json['word']          as String,
        partOfSpeech: json['part_of_speech'] as String,
        meaning:      json['meaning']        as String,
        example:      json['example']        as String,
      );
}

class CueCard {
  final int          id;
  final String       topic;
  final String       category;
  final List<String> prompts;
  final String       bandAnswer;
  final List<VocabWord> vocabulary;
  final List<String> tips;

  const CueCard({
    required this.id,
    required this.topic,
    required this.category,
    required this.prompts,
    required this.bandAnswer,
    required this.vocabulary,
    required this.tips,
  });

  factory CueCard.fromJson(Map<String, dynamic> json) => CueCard(
        id:         json['id']          as int,
        topic:      json['topic']       as String,
        category:   json['category']    as String,
        prompts:    List<String>.from(json['prompts'] as List),
        bandAnswer: json['band_answer'] as String,
        vocabulary: (json['vocabulary'] as List)
            .map((v) => VocabWord.fromJson(v as Map<String, dynamic>))
            .toList(),
        tips: List<String>.from(json['tips'] as List),
      );

  // Preview line shown in list tiles
  String get promptPreview => prompts.take(3).join(' · ');

  // Whether this card is free or premium
  bool get isFree => id <= kFreeCardLimit;
}

// ── Repository ────────────────────────────────────────────────────────────────

class CueCardRepository {
  static List<CueCard>? _cache;

  // Load all cards from JSON asset (cached after first load)
  static Future<List<CueCard>> loadAll() async {
    if (_cache != null) return _cache!;

    final jsonStr = await rootBundle.loadString('assets/data/cue_cards.json');
    final data    = json.decode(jsonStr) as Map<String, dynamic>;
    final list    = data['cards'] as List;

    _cache = list
        .map((e) => CueCard.fromJson(e as Map<String, dynamic>))
        .toList();

    return _cache!;
  }

  // Get card by ID
  static Future<CueCard?> getById(int id) async {
    final all = await loadAll();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Get cards by category
  static Future<List<CueCard>> getByCategory(String category) async {
    final all = await loadAll();
    if (category == 'All') return all;
    return all.where((c) => c.category == category).toList();
  }

  // Search cards by query
  static Future<List<CueCard>> search(String query) async {
    if (query.isEmpty) return loadAll();
    final all = await loadAll();
    final q   = query.toLowerCase();
    return all.where((c) =>
        c.topic.toLowerCase().contains(q) ||
        c.category.toLowerCase().contains(q)).toList();
  }

  // Get all unique categories
  static Future<List<String>> getCategories() async {
    final all  = await loadAll();
    final cats = all.map((c) => c.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  // Get all vocabulary words across all cards
  static Future<List<VocabWord>> getAllVocabulary() async {
    final all = await loadAll();
    return all.expand((c) => c.vocabulary).toList();
  }

  // Get a random card (all cards — for premium users)
  static Future<CueCard> getRandom() async {
    final all = await loadAll();
    all.shuffle();
    return all.first;
  }

  // ── NEW: Free tier helpers ─────────────────────────────────────────────────

  /// Returns true if a card ID is accessible to free users
  static bool isFreeCard(int cardId) => cardId <= kFreeCardLimit;

  /// Returns only the free cards (IDs 1–kFreeCardLimit)
  static Future<List<CueCard>> getFreeCards() async {
    final all = await loadAll();
    return all.where((c) => c.id <= kFreeCardLimit).toList();
  }

  /// Get a random card from the free pool only (for free users)
  static Future<CueCard> getRandomFree() async {
    final free = await getFreeCards();
    free.shuffle();
    return free.first;
  }

  // Clear cache (useful for hot reload during dev)
  static void clearCache() => _cache = null;
}