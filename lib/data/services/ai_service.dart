import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_secrets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/data/services/ai_service.dart
//
// Groq API (free, 14,400 req/day) for AI Speaking Coach.
// Uses Llama 3.3 70B — high quality, fast, and generous free tier.
// Sends user transcript + cue card details → returns structured IELTS feedback.
// ─────────────────────────────────────────────────────────────────────────────

class AiFeedback {
  final double overallBand;
  final double fluencyBand;
  final double lexicalBand;
  final double grammarBand;
  final double pronunciationBand;
  final String overallComment;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> suggestedVocabulary;
  final String improvedAnswer;
  final List<String> pronunciationFlags; // weak/mispronounced words

  const AiFeedback({
    required this.overallBand,
    required this.fluencyBand,
    required this.lexicalBand,
    required this.grammarBand,
    required this.pronunciationBand,
    required this.overallComment,
    required this.strengths,
    required this.improvements,
    required this.suggestedVocabulary,
    required this.improvedAnswer,
    this.pronunciationFlags = const [],
  });

  factory AiFeedback.fromJson(Map<String, dynamic> json) {
    double parseBand(dynamic v) {
      if (v is num) return v.toDouble().clamp(0.0, 9.0);
      if (v is String) return (double.tryParse(v) ?? 5.0).clamp(0.0, 9.0);
      return 5.0;
    }

    return AiFeedback(
      overallBand: parseBand(json['overall_band']),
      fluencyBand: parseBand(json['fluency_and_coherence']),
      lexicalBand: parseBand(json['lexical_resource']),
      grammarBand: parseBand(json['grammatical_range']),
      pronunciationBand: parseBand(json['pronunciation']),
      overallComment: json['overall_comment'] as String? ?? '',
      strengths: List<String>.from(json['strengths'] ?? []),
      improvements: List<String>.from(json['improvements'] ?? []),
      suggestedVocabulary:
          List<String>.from(json['suggested_vocabulary'] ?? []),
      improvedAnswer: json['improved_answer'] as String? ?? '',
      pronunciationFlags:
          List<String>.from(json['pronunciation_flags'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'overall_band': overallBand,
        'fluency_and_coherence': fluencyBand,
        'lexical_resource': lexicalBand,
        'grammatical_range': grammarBand,
        'pronunciation': pronunciationBand,
        'overall_comment': overallComment,
        'strengths': strengths,
        'improvements': improvements,
        'suggested_vocabulary': suggestedVocabulary,
        'improved_answer': improvedAnswer,
        'pronunciation_flags': pronunciationFlags,
      };
}

class AiService {
  AiService._();

  // ── Groq API — Get free key at https://console.groq.com/keys ──────────────
  // Free tier: 14,400 requests/day, 30 requests/minute
  // Much more generous than Gemini (1,500/day)
  static const String _apiKey = AppSecrets.groqApiKey;
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  /// Returns true if the API key has been configured
  static bool get isConfigured => _apiKey.startsWith('gsk_');

  /// Evaluate the user's spoken answer against the cue card
  static Future<AiFeedback> evaluateAnswer({
    required String topic,
    required List<String> prompts,
    required String userTranscript,
    required String sampleAnswer,
    required int speakingDurationSecs,
  }) async {
    final promptText = '''
You are an experienced IELTS Speaking examiner. Evaluate the following IELTS Speaking Part 2 response.

**Cue Card Topic:** $topic

**Cue Card Prompts:**
${prompts.map((p) => '- $p').join('\n')}

**Candidate's Response (transcribed from speech, ${speakingDurationSecs}s):**
"$userTranscript"

**Band 7-8 Sample Answer for reference:**
"$sampleAnswer"

Evaluate the candidate's response based on the four IELTS Speaking criteria. Since this is a speech-to-text transcription, be slightly lenient with punctuation/formatting but assess the content quality, vocabulary range, grammar accuracy, and coherence.

If the response is very short (under 30 words), too off-topic, or mostly incoherent, give appropriately low scores.

Return a JSON object with exactly this structure:
{
  "overall_band": <number 0-9 in 0.5 increments>,
  "fluency_and_coherence": <number 0-9 in 0.5 increments>,
  "lexical_resource": <number 0-9 in 0.5 increments>,
  "grammatical_range": <number 0-9 in 0.5 increments>,
  "pronunciation": <number 0-9 in 0.5 increments>,
  "overall_comment": "<2-3 sentence overall assessment>",
  "strengths": ["<strength 1>", "<strength 2>", "<strength 3>"],
  "improvements": ["<improvement 1>", "<improvement 2>", "<improvement 3>"],
  "suggested_vocabulary": ["<word/phrase: meaning — e.g. Breathtaking: extremely impressive>", "<word/phrase: meaning>", "<word/phrase: meaning>", "<word/phrase: meaning>"],
  "improved_answer": "<A concise improved version of the candidate's answer in 80-120 words, keeping their ideas but upgrading vocabulary and grammar>",
  "pronunciation_flags": ["<word1>", "<word2>", "<word3>"]
}

For "pronunciation_flags": identify 3-8 words from the candidate's transcript that are commonly mispronounced by non-native speakers, have unusual spelling-to-sound patterns, or appear to be incorrectly used (suggesting the speaker may not know how to pronounce them). Only include words that actually appear in the transcript. Return them in lowercase.

Return ONLY the raw JSON object. No markdown, no code fences, no extra text.
''';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      final request = await client.postUrl(Uri.parse(_baseUrl));
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');

      final body = json.encode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': promptText},
        ],
        'temperature': 0.4,
        'max_tokens': 2048,
        'response_format': {'type': 'json_object'},
      });
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      // Track API usage
      await _trackApiCall(response.statusCode);

      if (response.statusCode == 429) {
        throw Exception(
            'AI server is busy right now. Too many requests — please try again in a minute.');
      }

      if (response.statusCode != 200) {
        final errorData = json.decode(responseBody) as Map<String, dynamic>;
        final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Groq API error (${response.statusCode}): $errorMsg');
      }

      final data = json.decode(responseBody) as Map<String, dynamic>;
      final text =
          data['choices']?[0]?['message']?['content']?.toString().trim() ?? '';

      if (text.isEmpty) {
        throw Exception('Empty response from AI');
      }

      // Parse JSON — may be wrapped in ```json``` blocks
      String jsonStr = text;
      if (jsonStr.contains('```')) {
        final match =
            RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
        if (match != null) jsonStr = match.group(1)!.trim();
      }

      final parsed = json.decode(jsonStr) as Map<String, dynamic>;
      client.close();
      return AiFeedback.fromJson(parsed);
    } catch (e) {
      debugPrint('AI evaluation error: $e');
      rethrow;
    }
  }

  /// Evaluate a Part 1 or Part 3 spoken answer (no cue card)
  static Future<AiFeedback> evaluateDailyAnswer({
    required String question,
    required String partType,
    required String userTranscript,
    required int speakingDurationSecs,
  }) async {
    final isP1 = partType == 'Part 1';
    final promptText = '''
You are an experienced IELTS Speaking examiner. Evaluate the following IELTS Speaking $partType response.

**Question:** $question

**Candidate's Response (transcribed from speech, ${speakingDurationSecs}s):**
"$userTranscript"

Evaluate the candidate's response based on the four IELTS Speaking criteria. Since this is a speech-to-text transcription, be slightly lenient with punctuation/formatting but assess the content quality, vocabulary range, grammar accuracy, and coherence.

For $partType:
${isP1 ? '- Answers should be 2-4 sentences, natural and personal.\n- Penalize overly short (1-2 word) or overly long rambling answers.' : '- Answers should be analytical, well-structured, with examples.\n- Assess depth of reasoning and ability to discuss abstract topics.'}

If the response is very short (under 10 words), too off-topic, or mostly incoherent, give appropriately low scores.

Return a JSON object with exactly this structure:
{
  "overall_band": <number 0-9 in 0.5 increments>,
  "fluency_and_coherence": <number 0-9 in 0.5 increments>,
  "lexical_resource": <number 0-9 in 0.5 increments>,
  "grammatical_range": <number 0-9 in 0.5 increments>,
  "pronunciation": <number 0-9 in 0.5 increments>,
  "overall_comment": "<2-3 sentence overall assessment>",
  "strengths": ["<strength 1>", "<strength 2>"],
  "improvements": ["<improvement 1>", "<improvement 2>"],
  "suggested_vocabulary": ["<word/phrase: meaning>", "<word/phrase: meaning>", "<word/phrase: meaning>"],
  "improved_answer": "<A concise improved version of the candidate's answer in ${isP1 ? '20-40' : '40-80'} words, keeping their ideas but upgrading vocabulary and grammar>",
  "pronunciation_flags": ["<word1>", "<word2>", "<word3>"]
}

For "pronunciation_flags": identify 2-5 words from the candidate's transcript that are commonly mispronounced by non-native speakers. Only include words actually in the transcript. Return lowercase.

Return ONLY the raw JSON object. No markdown, no code fences, no extra text.
''';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      final request = await client.postUrl(Uri.parse(_baseUrl));
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');

      final body = json.encode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': promptText},
        ],
        'temperature': 0.4,
        'max_tokens': 1536,
        'response_format': {'type': 'json_object'},
      });
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      await _trackApiCall(response.statusCode);

      if (response.statusCode == 429) {
        throw Exception(
            'AI server is busy right now. Please try again in a minute.');
      }
      if (response.statusCode != 200) {
        final errorData = json.decode(responseBody) as Map<String, dynamic>;
        final errorMsg = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception('Groq API error (${response.statusCode}): $errorMsg');
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
      return AiFeedback.fromJson(parsed);
    } catch (e) {
      debugPrint('Daily answer evaluation error: $e');
      rethrow;
    }
  }

  /// Generate a daily AI practice question (Part 1 or Part 3)
  /// Returns a map with 'question' and 'part' keys.
  static Future<Map<String, String>> generateDailyQuestion() async {
    final dayOfYear = DateTime.now().difference(DateTime(2026)).inDays;
    final promptText = '''
You are an IELTS Speaking examiner. Generate ONE fresh, original IELTS Speaking practice question.

Today's seed number: $dayOfYear (use this to vary the topic).

Randomly choose either Part 1 or Part 3. 
- Part 1 questions are simple personal questions (e.g., about hobbies, hometown, daily routine).
- Part 3 questions are abstract/analytical (e.g., about society, technology, education trends).

Return a JSON object with exactly this structure:
{
  "part": "Part 1" or "Part 3",
  "question": "<the question text>"
}

Return ONLY the raw JSON object. No markdown, no code fences, no extra text.
''';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      final request = await client.postUrl(Uri.parse(_baseUrl));
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');

      final body = json.encode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': promptText},
        ],
        'temperature': 0.9,
        'max_tokens': 256,
        'response_format': {'type': 'json_object'},
      });
      request.add(utf8.encode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      await _trackApiCall(response.statusCode);

      if (response.statusCode != 200) {
        throw Exception('Failed to generate daily question');
      }

      final data = json.decode(responseBody) as Map<String, dynamic>;
      final text =
          data['choices']?[0]?['message']?['content']?.toString().trim() ?? '';

      String jsonStr = text;
      if (jsonStr.contains('```')) {
        final match =
            RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
        if (match != null) jsonStr = match.group(1)!.trim();
      }

      final parsed = json.decode(jsonStr) as Map<String, dynamic>;
      client.close();

      return {
        'question': parsed['question'] as String? ?? 'What do you enjoy doing in your free time?',
        'part': parsed['part'] as String? ?? 'Part 1',
      };
    } catch (e) {
      debugPrint('Daily question generation error: $e');
      // Fallback question if API fails
      return {
        'question': 'What do you enjoy doing in your free time?',
        'part': 'Part 1',
      };
    }
  }

  // ── API Usage Tracking ──────────────────────────────────────────────────
  static const _kApiTotalCalls = 'ai_api_total_calls';
  static const _kApiTotalFails = 'ai_api_total_fails';
  static const _kApiRateLimits = 'ai_api_rate_limits';
  static const _kApiLastError = 'ai_api_last_error';

  static Future<void> _trackApiCall(int statusCode) async {
    try {
      final p = await SharedPreferences.getInstance();
      final total = (p.getInt(_kApiTotalCalls) ?? 0) + 1;
      await p.setInt(_kApiTotalCalls, total);

      if (statusCode != 200) {
        await p.setInt(_kApiTotalFails, (p.getInt(_kApiTotalFails) ?? 0) + 1);
        await p.setString(_kApiLastError,
            '${DateTime.now().toIso8601String()} | HTTP $statusCode');
      }
      if (statusCode == 429) {
        await p.setInt(_kApiRateLimits, (p.getInt(_kApiRateLimits) ?? 0) + 1);
      }
    } catch (_) {}
  }

  /// Get API usage stats (for developer monitoring)
  static Future<Map<String, dynamic>> getApiStats() async {
    final p = await SharedPreferences.getInstance();
    return {
      'total_calls': p.getInt(_kApiTotalCalls) ?? 0,
      'total_fails': p.getInt(_kApiTotalFails) ?? 0,
      'rate_limits': p.getInt(_kApiRateLimits) ?? 0,
      'last_error': p.getString(_kApiLastError) ?? 'none',
    };
  }
}
