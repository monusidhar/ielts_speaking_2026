import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/repositories/speaking_question_repository.dart
//
// Loads Part 1 and Part 3 speaking questions from bundled JSON.
// ─────────────────────────────────────────────────────────────────────────────

class SpeakingQuestion {
  final String question;
  final String sampleAnswer;

  SpeakingQuestion({required this.question, required this.sampleAnswer});

  factory SpeakingQuestion.fromJson(Map<String, dynamic> json) {
    return SpeakingQuestion(
      question: json['question'] as String,
      sampleAnswer: json['sample_answer'] as String,
    );
  }
}

class VocabularyItem {
  final String word;
  final String meaning;

  VocabularyItem({required this.word, required this.meaning});

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      word: json['word'] as String,
      meaning: json['meaning'] as String,
    );
  }
}

class SpeakingTopic {
  final int id;
  final String topic;
  final List<SpeakingQuestion> questions;
  final List<String> tips;
  final List<VocabularyItem> vocabulary;
  final List<String>? relatedCategories; // Part 3 only

  SpeakingTopic({
    required this.id,
    required this.topic,
    required this.questions,
    required this.tips,
    required this.vocabulary,
    this.relatedCategories,
  });

  /// Convenience: list of question strings only (for timer screen)
  List<String> get questionTexts => questions.map((q) => q.question).toList();

  factory SpeakingTopic.fromJson(Map<String, dynamic> json) {
    return SpeakingTopic(
      id: json['id'] as int,
      topic: json['topic'] as String,
      questions: (json['questions'] as List)
          .map((q) => SpeakingQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      tips: List<String>.from(json['tips'] as List),
      vocabulary: (json['vocabulary'] as List)
          .map((v) => VocabularyItem.fromJson(v as Map<String, dynamic>))
          .toList(),
      relatedCategories: json['related_categories'] != null
          ? List<String>.from(json['related_categories'] as List)
          : null,
    );
  }
}

class SpeakingQuestionRepository {
  SpeakingQuestionRepository._();

  static List<SpeakingTopic>? _part1Topics;
  static List<SpeakingTopic>? _part3Topics;

  static Future<void> _ensureLoaded() async {
    if (_part1Topics != null && _part3Topics != null) return;

    final jsonStr =
        await rootBundle.loadString('assets/data/speaking_questions.json');
    final data = json.decode(jsonStr) as Map<String, dynamic>;

    final p1List = data['part1']['topics'] as List;
    _part1Topics = p1List.map((e) => SpeakingTopic.fromJson(e)).toList();

    final p3List = data['part3']['topics'] as List;
    _part3Topics = p3List.map((e) => SpeakingTopic.fromJson(e)).toList();
  }

  static Future<List<SpeakingTopic>> getPart1Topics() async {
    await _ensureLoaded();
    return _part1Topics!;
  }

  static Future<List<SpeakingTopic>> getPart3Topics() async {
    await _ensureLoaded();
    return _part3Topics!;
  }

  static Future<SpeakingTopic> getRandomPart1() async {
    await _ensureLoaded();
    return _part1Topics![Random().nextInt(_part1Topics!.length)];
  }

  static Future<SpeakingTopic> getRandomPart3() async {
    await _ensureLoaded();
    return _part3Topics![Random().nextInt(_part3Topics!.length)];
  }
}
