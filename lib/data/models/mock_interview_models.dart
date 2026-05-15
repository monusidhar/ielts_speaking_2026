// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/models/mock_interview_models.dart
//
// Data classes for the Full Mock Interview feature (Parts 1 + 2 + 3).
// ─────────────────────────────────────────────────────────────────────────────

class MockPart1Topic {
  final String topic;
  final List<String> questions;

  const MockPart1Topic({required this.topic, required this.questions});

  factory MockPart1Topic.fromJson(Map<String, dynamic> json) {
    return MockPart1Topic(
      topic: json['topic'] as String? ?? '',
      questions: List<String>.from(json['questions'] ?? []),
    );
  }
}

class MockInterviewQuestions {
  final List<MockPart1Topic> part1Topics;
  final List<String> part3Questions;

  const MockInterviewQuestions({
    required this.part1Topics,
    required this.part3Questions,
  });

  factory MockInterviewQuestions.fromJson(Map<String, dynamic> json) {
    return MockInterviewQuestions(
      part1Topics: (json['part1_topics'] as List?)
              ?.map((e) => MockPart1Topic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      part3Questions: List<String>.from(json['part3_questions'] ?? []),
    );
  }

  List<String> get allPart1Questions =>
      part1Topics.expand((t) => t.questions).toList();
}

class MockQATranscript {
  final String question;
  final String transcript;
  final int durationSecs;

  const MockQATranscript({
    required this.question,
    required this.transcript,
    this.durationSecs = 0,
  });
}

class MockInterviewResult {
  final double overallBand;
  final double fluencyBand;
  final double lexicalBand;
  final double grammarBand;
  final double pronunciationBand;
  final double part1Band;
  final double part2Band;
  final double part3Band;
  final String overallComment;
  final String part1Feedback;
  final String part2Feedback;
  final String part3Feedback;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> suggestedVocabulary;
  final String improvedPart2Answer;

  const MockInterviewResult({
    required this.overallBand,
    required this.fluencyBand,
    required this.lexicalBand,
    required this.grammarBand,
    required this.pronunciationBand,
    required this.part1Band,
    required this.part2Band,
    required this.part3Band,
    required this.overallComment,
    required this.part1Feedback,
    required this.part2Feedback,
    required this.part3Feedback,
    required this.strengths,
    required this.improvements,
    required this.suggestedVocabulary,
    required this.improvedPart2Answer,
  });

  factory MockInterviewResult.fromJson(Map<String, dynamic> json) {
    double parseBand(dynamic v) {
      if (v is num) return v.toDouble().clamp(0.0, 9.0);
      if (v is String) return (double.tryParse(v) ?? 5.0).clamp(0.0, 9.0);
      return 5.0;
    }

    return MockInterviewResult(
      overallBand: parseBand(json['overall_band']),
      fluencyBand: parseBand(json['fluency_and_coherence']),
      lexicalBand: parseBand(json['lexical_resource']),
      grammarBand: parseBand(json['grammatical_range']),
      pronunciationBand: parseBand(json['pronunciation']),
      part1Band: parseBand(json['part1_band']),
      part2Band: parseBand(json['part2_band']),
      part3Band: parseBand(json['part3_band']),
      overallComment: json['overall_comment'] as String? ?? '',
      part1Feedback: json['part1_feedback'] as String? ?? '',
      part2Feedback: json['part2_feedback'] as String? ?? '',
      part3Feedback: json['part3_feedback'] as String? ?? '',
      strengths: List<String>.from(json['strengths'] ?? []),
      improvements: List<String>.from(json['improvements'] ?? []),
      suggestedVocabulary:
          List<String>.from(json['suggested_vocabulary'] ?? []),
      improvedPart2Answer: json['improved_part2_answer'] as String? ?? '',
    );
  }
}
