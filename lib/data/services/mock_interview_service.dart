import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../app_secrets.dart';
import '../models/mock_interview_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/services/mock_interview_service.dart
//
// Two AI calls per mock interview:
//   1) generateQuestions  — creates Part 1 + Part 3 questions
//   2) evaluateInterview  — scores the full test
// Uses the same Groq API / Llama 3.3 70B as ai_service.dart.
// ─────────────────────────────────────────────────────────────────────────────

class MockInterviewService {
  MockInterviewService._();

  static const String _apiKey = AppSecrets.groqApiKey;
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  static bool get isConfigured => _apiKey.startsWith('gsk_');

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Generate Part 1 + Part 3 questions (one API call)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<MockInterviewQuestions> generateQuestions({
    required String cueCardTopic,
    required String cueCardCategory,
  }) async {
    final prompt = '''
You are an experienced IELTS Speaking examiner preparing a full mock test.

The Part 2 cue card topic is: "$cueCardTopic" (Category: $cueCardCategory)

Generate questions for Parts 1 and 3:

**Part 1 (Introduction & Interview):**
- Choose 2 common everyday topics DIFFERENT from "$cueCardCategory"
  (e.g., Home, Daily Routine, Weather, Hobbies, Friends, Shopping, Music, Reading, Sports, Cooking, Holidays, Transportation)
- For each topic, write exactly 3 natural examiner questions
- Questions should be simple, conversational, and realistic

**Part 3 (Two-way Discussion):**
- Write exactly 4 abstract/analytical questions related to the broader theme of "$cueCardTopic"
- These should require deeper thinking, opinions, comparisons, or predictions
- More complex than Part 1 questions

Return ONLY a JSON object with this exact structure:
{
  "part1_topics": [
    {"topic": "Topic Name", "questions": ["Q1?", "Q2?", "Q3?"]},
    {"topic": "Topic Name", "questions": ["Q1?", "Q2?", "Q3?"]}
  ],
  "part3_questions": ["Q1?", "Q2?", "Q3?", "Q4?"]
}

Return ONLY the raw JSON. No markdown, no code fences, no extra text.
''';

    return _callApi<MockInterviewQuestions>(
      prompt: prompt,
      parser: (json) => MockInterviewQuestions.fromJson(json),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Evaluate the complete interview (one API call)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<MockInterviewResult> evaluateInterview({
    required String cueCardTopic,
    required List<String> cueCardPrompts,
    required String sampleAnswer,
    required List<MockQATranscript> part1Transcripts,
    required String part2Transcript,
    required int part2DurationSecs,
    required List<MockQATranscript> part3Transcripts,
  }) async {
    final part1Section = part1Transcripts
        .map((qa) =>
            'Q: ${qa.question}\nA: "${qa.transcript.isEmpty ? "(no response)" : qa.transcript}" (${qa.durationSecs}s)')
        .join('\n\n');

    final part3Section = part3Transcripts
        .map((qa) =>
            'Q: ${qa.question}\nA: "${qa.transcript.isEmpty ? "(no response)" : qa.transcript}" (${qa.durationSecs}s)')
        .join('\n\n');

    final prompt = '''
You are an experienced IELTS Speaking examiner. Evaluate this complete IELTS Speaking mock test.

═══ PART 1 — Introduction & Interview ═══
$part1Section

═══ PART 2 — Long Turn (Cue Card) ═══
Topic: $cueCardTopic
Prompts:
${cueCardPrompts.map((p) => '• $p').join('\n')}

Candidate's response (${part2DurationSecs}s):
"${part2Transcript.isEmpty ? "(no response)" : part2Transcript}"

Band 7-8 sample answer for reference:
"$sampleAnswer"

═══ PART 3 — Two-way Discussion ═══
$part3Section

═══ EVALUATION INSTRUCTIONS ═══
Evaluate holistically across ALL three parts. Since these are speech-to-text transcriptions, be slightly lenient with punctuation but assess content, vocabulary, grammar, and coherence strictly.

If responses are very short, off-topic, or incoherent, give appropriately low scores.

Return ONLY a JSON object with this exact structure:
{
  "overall_band": <number 0-9 in 0.5 increments>,
  "fluency_and_coherence": <number 0-9 in 0.5 increments>,
  "lexical_resource": <number 0-9 in 0.5 increments>,
  "grammatical_range": <number 0-9 in 0.5 increments>,
  "pronunciation": <number 0-9 in 0.5 increments>,
  "part1_band": <number 0-9 in 0.5 increments>,
  "part2_band": <number 0-9 in 0.5 increments>,
  "part3_band": <number 0-9 in 0.5 increments>,
  "overall_comment": "<3-4 sentence overall assessment>",
  "part1_feedback": "<2-3 sentences about Part 1 performance>",
  "part2_feedback": "<2-3 sentences about Part 2 performance>",
  "part3_feedback": "<2-3 sentences about Part 3 performance>",
  "strengths": ["<strength 1>", "<strength 2>", "<strength 3>"],
  "improvements": ["<improvement 1>", "<improvement 2>", "<improvement 3>"],
  "suggested_vocabulary": ["<word: meaning>", "<word: meaning>", "<word: meaning>", "<word: meaning>", "<word: meaning>"],
  "improved_part2_answer": "<Improved version of the candidate's Part 2 answer in 80-120 words, keeping their ideas but upgrading vocabulary and grammar>"
}

Return ONLY the raw JSON. No markdown, no code fences, no extra text.
''';

    return _callApi<MockInterviewResult>(
      prompt: prompt,
      parser: (json) => MockInterviewResult.fromJson(json),
      maxTokens: 3000,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared API caller
  // ─────────────────────────────────────────────────────────────────────────

  static Future<T> _callApi<T>({
    required String prompt,
    required T Function(Map<String, dynamic>) parser,
    int maxTokens = 2048,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      final request = await client.postUrl(Uri.parse(_baseUrl));
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');

      final body = json.encode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.4,
        'max_tokens': maxTokens,
        'response_format': {'type': 'json_object'},
      });
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 429) {
        throw Exception(
            'AI server is busy right now. Please try again in a minute.');
      }

      if (response.statusCode != 200) {
        final errorData = json.decode(responseBody) as Map<String, dynamic>;
        final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('AI error (${response.statusCode}): $errorMsg');
      }

      final data = json.decode(responseBody) as Map<String, dynamic>;
      final text =
          data['choices']?[0]?['message']?['content']?.toString().trim() ?? '';

      if (text.isEmpty) throw Exception('Empty response from AI');

      String jsonStr = text;
      if (jsonStr.contains('```')) {
        final match =
            RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
        if (match != null) jsonStr = match.group(1)!.trim();
      }

      final parsed = json.decode(jsonStr) as Map<String, dynamic>;
      client.close();
      return parser(parsed);
    } catch (e) {
      debugPrint('Mock interview API error: $e');
      rethrow;
    }
  }
}
