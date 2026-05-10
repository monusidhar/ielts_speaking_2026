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
  "improved_answer": "<A concise improved version of the candidate's answer in 80-120 words, keeping their ideas but upgrading vocabulary and grammar>"
}

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
