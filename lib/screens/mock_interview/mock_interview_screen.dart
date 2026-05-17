import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../data/models/mock_interview_models.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../data/services/mock_interview_service.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/review_service.dart';
import '../../data/services/notification_service.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/mock_interview/mock_interview_screen.dart
//
// Full Mock Interview — conducts Part 1, Part 2, Part 3 in sequence.
// Uses speech_to_text for recording, Groq AI for question generation
// and final evaluation.
// ─────────────────────────────────────────────────────────────────────────────

// ── Timing constants ────────────────────────────────────────────────────────
const int kPart1SecsPerQ = 30; // 30s per Part 1 question
const int kPart2PrepSecs = 60; // 1 min cue card prep
const int kPart2SpeakSecs = 120; // 2 min cue card speaking
const int kPart3SecsPerQ = 45; // 45s per Part 3 question
const int kPartIntroDurationMs = 2500; // Part intro display time

enum _Phase {
  loading, // Generating questions
  part1Intro, // "Part 1" title screen
  part1Question, // Part 1 Q&A
  part2Intro, // "Part 2" title screen
  part2Prep, // Cue card preparation
  part2Speaking, // Cue card speaking
  part3Intro, // "Part 3" title screen
  part3Question, // Part 3 Q&A
  analyzing, // AI evaluation
}

class MockInterviewScreen extends StatefulWidget {
  const MockInterviewScreen({super.key});
  @override
  State<MockInterviewScreen> createState() => _MockInterviewScreenState();
}

class _MockInterviewScreenState extends State<MockInterviewScreen>
    with TickerProviderStateMixin {
  // ── Data ─────────────────────────────────────────────────────────────────
  CueCard? _card;
  MockInterviewQuestions? _questions;
  String? _error;

  // ── Phase tracking ──────────────────────────────────────────────────────
  _Phase _phase = _Phase.loading;
  int _currentQIndex = 0; // Index into current question list
  int _secsLeft = 0;
  Timer? _timer;
  bool _isRecording = false;
  int _questionStartTime = 0; // epoch seconds when recording started

  // ── Transcripts ─────────────────────────────────────────────────────────
  final List<MockQATranscript> _part1Transcripts = [];
  String _part2Transcript = '';
  int _part2Duration = 0;
  final List<MockQATranscript> _part3Transcripts = [];

  // ── Speech recognition ──────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String _currentTranscript = '';
  String _partialText = '';
  int _restartCount = 0;
  bool _isRestarting = false;
  Timer? _safetyTimer;

  // ── Animations ──────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Computed helpers ────────────────────────────────────────────────────
  List<String> get _part1Qs => _questions?.allPart1Questions ?? [];
  List<String> get _part3Qs => _questions?.part3Questions ?? [];
  String get _currentQuestion {
    if (_phase == _Phase.part1Question && _currentQIndex < _part1Qs.length) {
      return _part1Qs[_currentQIndex];
    }
    if (_phase == _Phase.part3Question && _currentQIndex < _part3Qs.length) {
      return _part3Qs[_currentQIndex];
    }
    return '';
  }

  String get _fullTranscript {
    if (_partialText.isEmpty) return _currentTranscript;
    if (_currentTranscript.isEmpty) return _partialText;
    return '$_currentTranscript $_partialText';
  }

  int get _totalPart1 => _part1Qs.length;
  int get _totalPart3 => _part3Qs.length;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _initSpeech();
    _loadAndGenerate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _safetyTimer?.cancel();
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        if (_isRecording && mounted) _restartListening();
      },
      onStatus: (status) {
        if (status == 'done' && _isRecording && mounted) _restartListening();
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadAndGenerate() async {
    try {
      // Pick a random cue card
      final card = PrefsRepository.isPremium()
          ? await CueCardRepository.getRandom()
          : await CueCardRepository.getRandomFree();

      if (!mounted) return;
      setState(() => _card = card);

      if (!MockInterviewService.isConfigured) {
        throw Exception('AI service not configured. Please contact support.');
      }

      // Generate Part 1 + Part 3 questions
      final questions = await MockInterviewService.generateQuestions(
        cueCardTopic: card.topic,
        cueCardCategory: card.category,
      );

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _phase = _Phase.part1Intro;
      });
      _autoAdvanceIntro(_Phase.part1Question);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = 'Failed to prepare interview: ${_truncate(e.toString())}');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE TRANSITIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _autoAdvanceIntro(_Phase nextPhase) {
    Future.delayed(const Duration(milliseconds: kPartIntroDurationMs), () {
      if (!mounted) return;
      setState(() {
        _phase = nextPhase;
        _currentQIndex = 0;
        _isRecording = false;
        _currentTranscript = '';
        _partialText = '';
      });
    });
  }

  void _startRecordingForQuestion() {
    HapticFeedback.mediumImpact();
    final maxSecs =
        _phase == _Phase.part1Question ? kPart1SecsPerQ : kPart3SecsPerQ;
    setState(() {
      _isRecording = true;
      _secsLeft = maxSecs;
      _currentTranscript = '';
      _partialText = '';
      _questionStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    });
    _startTimer();
    _doListen();
  }

  void _startPart2Prep() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.part2Prep;
      _secsLeft = kPart2PrepSecs;
    });
    _startTimer();
  }

  void _startPart2Speaking() {
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.part2Speaking;
      _secsLeft = kPart2SpeakSecs;
      _isRecording = true;
      _currentTranscript = '';
      _partialText = '';
      _questionStartTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    });
    _startTimer();
    _doListen();
  }

  void _finishCurrentQuestion() {
    _timer?.cancel();
    _safetyTimer?.cancel();
    _speech.stop();

    // Finalize transcript
    if (_partialText.isNotEmpty) {
      if (_currentTranscript.isNotEmpty) _currentTranscript += ' ';
      _currentTranscript += _partialText;
      _partialText = '';
    }

    final duration =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _questionStartTime;
    final transcript = MockQATranscript(
      question: _currentQuestion,
      transcript: _currentTranscript.trim(),
      durationSecs: duration,
    );

    if (_phase == _Phase.part1Question) {
      _part1Transcripts.add(transcript);
      final nextIdx = _currentQIndex + 1;
      if (nextIdx < _totalPart1) {
        // Next Part 1 question
        setState(() {
          _currentQIndex = nextIdx;
          _isRecording = false;
          _currentTranscript = '';
          _partialText = '';
        });
      } else {
        // Part 1 done → Part 2 intro
        setState(() {
          _phase = _Phase.part2Intro;
          _isRecording = false;
          _currentTranscript = '';
          _partialText = '';
        });
        // After intro, start Part 2 prep with timer
        Future.delayed(const Duration(milliseconds: kPartIntroDurationMs), () {
          if (!mounted) return;
          _startPart2Prep();
        });
      }
    } else if (_phase == _Phase.part3Question) {
      _part3Transcripts.add(transcript);
      final nextIdx = _currentQIndex + 1;
      if (nextIdx < _totalPart3) {
        // Next Part 3 question
        setState(() {
          _currentQIndex = nextIdx;
          _isRecording = false;
          _currentTranscript = '';
          _partialText = '';
        });
      } else {
        // All done → analyze
        _startAnalyzing();
      }
    }
  }

  void _finishPart2Speaking() {
    _timer?.cancel();
    _safetyTimer?.cancel();
    _speech.stop();

    if (_partialText.isNotEmpty) {
      if (_currentTranscript.isNotEmpty) _currentTranscript += ' ';
      _currentTranscript += _partialText;
      _partialText = '';
    }

    _part2Transcript = _currentTranscript.trim();
    _part2Duration =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) - _questionStartTime;

    setState(() {
      _phase = _Phase.part3Intro;
      _isRecording = false;
      _currentTranscript = '';
      _partialText = '';
    });
    _autoAdvanceIntro(_Phase.part3Question);
  }

  Future<void> _startAnalyzing() async {
    setState(() {
      _phase = _Phase.analyzing;
      _isRecording = false;
    });

    // Capture navigator before async gap
    final navigator = Navigator.of(context);

    try {
      final result = await MockInterviewService.evaluateInterview(
        cueCardTopic: _card!.topic,
        cueCardPrompts: _card!.prompts,
        sampleAnswer: _card!.bandAnswer,
        part1Transcripts: _part1Transcripts,
        part2Transcript: _part2Transcript,
        part2DurationSecs: _part2Duration,
        part3Transcripts: _part3Transcripts,
      );

      // Track usage
      await PrefsRepository.incrementMockCount();
      await PrefsRepository.markPracticed(_card!.id);
      await PrefsRepository.recordStreakToday();

      // Show interstitial ad before results
      await AdService.showVideoAdAfterAiPractice();
      ReviewService.maybeRequestReview(result.overallBand);
      NotificationService.onPracticeCompleted();

      if (!mounted) return;
      // Navigate to results
      navigator.pushReplacementNamed(
        AppRoutes.mockInterviewResult,
        arguments: {
          'result': result,
          'card': _card,
        },
      );
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = 'AI evaluation failed: ${_truncate(e.toString())}');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TIMER
  // ─────────────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secsLeft <= 1) {
        _timer?.cancel();
        HapticFeedback.vibrate();
        if (_phase == _Phase.part2Prep) {
          _startPart2Speaking();
        } else if (_phase == _Phase.part2Speaking) {
          _finishPart2Speaking();
        } else if (_phase == _Phase.part1Question ||
            _phase == _Phase.part3Question) {
          if (_isRecording) _finishCurrentQuestion();
        }
      } else {
        setState(() => _secsLeft--);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SPEECH RECOGNITION (same pattern as ai_practice_screen)
  // ─────────────────────────────────────────────────────────────────────────

  void _doListen() {
    if (!_isRecording || !_speechAvailable || !mounted) return;
    _isRestarting = false;
    _restartCount = 0;
    _speech.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 55),
      pauseFor: const Duration(seconds: 30),
      partialResults: true,
      localeId: 'en_US',
    );
    _safetyTimer?.cancel();
    _safetyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isRecording || !mounted) {
        _safetyTimer?.cancel();
        return;
      }
      if (!_speech.isListening && !_isRestarting) _restartListening();
    });
  }

  void _restartListening() {
    if (!_isRecording || !_speechAvailable || _isRestarting) return;
    _isRestarting = true;
    _restartCount++;
    if (_restartCount > 30) return;
    _speech.cancel().then((_) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_isRecording && mounted) _doListen();
      });
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      if (result.finalResult) {
        if (_currentTranscript.isNotEmpty &&
            result.recognizedWords.isNotEmpty) {
          _currentTranscript += ' ';
        }
        _currentTranscript += result.recognizedWords;
        _partialText = '';
        if (_isRecording) _restartListening();
      } else {
        _partialText = result.recognizedWords;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUIT CONFIRMATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_phase == _Phase.loading || _error != null) return true;
    if (_phase == _Phase.analyzing) return false; // can't quit during analysis

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Interview?'),
        content: const Text(
            'Your progress will be lost and this will count as your attempt.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continue')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Quit',
                  style: TextStyle(color: Color(0xFFC62828)))),
        ],
      ),
    );
    return result ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _truncate(String s) => s.length > 200 ? s.substring(0, 200) : s;

  int get _overallProgress {
    // Total questions: P1(6) + P2(1) + P3(4) = 11 steps
    if (_phase == _Phase.loading) return 0;
    if (_phase == _Phase.part1Intro) return 0;
    if (_phase == _Phase.part1Question) return _part1Transcripts.length;
    if (_phase == _Phase.part2Intro) return _totalPart1;
    if (_phase == _Phase.part2Prep) return _totalPart1;
    if (_phase == _Phase.part2Speaking) return _totalPart1;
    if (_phase == _Phase.part3Intro) return _totalPart1 + 1;
    if (_phase == _Phase.part3Question) {
      return _totalPart1 + 1 + _part3Transcripts.length;
    }
    if (_phase == _Phase.analyzing) return _totalPart1 + 1 + _totalPart3;
    return 0;
  }

  int get _totalSteps => _totalPart1 + 1 + _totalPart3;

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
        appBar: _phase == _Phase.loading ||
                _phase == _Phase.part1Intro ||
                _phase == _Phase.part2Intro ||
                _phase == _Phase.part3Intro ||
                _phase == _Phase.analyzing
            ? null
            : AppBar(
                title: Text(_appBarTitle),
                backgroundColor:
                    isDark ? const Color(0xFF0F1B2D) : _phaseColor(_phase),
                foregroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: _phase != _Phase.analyzing,
              ),
        body: _error != null ? _buildError(isDark) : _buildPhase(isDark),
      ),
    );
  }

  String get _appBarTitle {
    switch (_phase) {
      case _Phase.part1Question:
        return 'Part 1 — Q${_currentQIndex + 1}/$_totalPart1';
      case _Phase.part2Prep:
      case _Phase.part2Speaking:
        return 'Part 2 — Cue Card';
      case _Phase.part3Question:
        return 'Part 3 — Q${_currentQIndex + 1}/$_totalPart3';
      default:
        return 'Mock Interview';
    }
  }

  Color _phaseColor(_Phase p) {
    switch (p) {
      case _Phase.part1Intro:
      case _Phase.part1Question:
        return const Color(0xFF1565C0);
      case _Phase.part2Intro:
      case _Phase.part2Prep:
      case _Phase.part2Speaking:
        return const Color(0xFF2E7D32);
      case _Phase.part3Intro:
      case _Phase.part3Question:
        return const Color(0xFFE65100);
      default:
        return const Color(0xFF6A1B9A);
    }
  }

  Widget _buildPhase(bool isDark) {
    switch (_phase) {
      case _Phase.loading:
        return _buildLoading(isDark);
      case _Phase.part1Intro:
        return _buildPartIntro(
            isDark,
            '1',
            'Introduction & Interview',
            'Answer short questions on everyday topics',
            const Color(0xFF1565C0));
      case _Phase.part2Intro:
        return _buildPartIntro(
            isDark,
            '2',
            'Long Turn — Cue Card',
            'Prepare for 1 minute, then speak for 2 minutes',
            const Color(0xFF2E7D32));
      case _Phase.part3Intro:
        return _buildPartIntro(
            isDark,
            '3',
            'Two-way Discussion',
            'Deeper questions related to the cue card topic',
            const Color(0xFFE65100));
      case _Phase.part1Question:
      case _Phase.part3Question:
        return _buildQAPhase(isDark);
      case _Phase.part2Prep:
        return _buildPart2Prep(isDark);
      case _Phase.part2Speaking:
        return _buildPart2Speaking(isDark);
      case _Phase.analyzing:
        return _buildAnalyzing(isDark);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF6A1B9A) : const Color(0xFF8E24AA)),
            ),
          ),
          const SizedBox(height: 28),
          Text('Preparing your interview...',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('AI is generating questions',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF8899AA)
                      : const Color(0xFF555577))),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PART INTRO SCREENS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPartIntro(
      bool isDark, String number, String title, String subtitle, Color color) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color,
            color.withOpacity(0.85),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text('P$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            Text('Part $number',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 40),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PART 1 / PART 3 — QUESTION & ANSWER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQAPhase(bool isDark) {
    final isPart1 = _phase == _Phase.part1Question;
    final color = isPart1 ? const Color(0xFF1565C0) : const Color(0xFFE65100);
    final maxSecs = isPart1 ? kPart1SecsPerQ : kPart3SecsPerQ;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(children: [
        // Progress bar
        _buildProgressBar(isDark),
        const SizedBox(height: 20),

        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ],
          ),
          child: Column(children: [
            Icon(Icons.chat_bubble_outline_rounded, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              _currentQuestion,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E),
                height: 1.5,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // Timer ring + mic
        if (_isRecording) ...[
          _buildTimerRing(isDark, color, maxSecs),
          const SizedBox(height: 16),
          // Live transcript
          if (_fullTranscript.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A2E4A).withOpacity(0.5)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _fullTranscript,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355),
                    height: 1.5,
                    fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 20),
          // Next button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _finishCurrentQuestion,
              icon: const Icon(Icons.skip_next_rounded, size: 20),
              label: Text(
                _isLastQuestion ? 'Finish & Continue' : 'Next Question',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ] else ...[
          // Start speaking button
          GestureDetector(
            onTap: _speechAvailable ? _startRecordingForQuestion : null,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color.withOpacity(0.3), width: 2),
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded, color: color, size: 36),
                    const SizedBox(height: 4),
                    Text('Tap to speak',
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          ),
          if (!_speechAvailable) ...[
            const SizedBox(height: 12),
            Text('Microphone not available',
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFFC62828)
                        : const Color(0xFFC62828),
                    fontSize: 12)),
          ],
        ],
      ]),
    );
  }

  bool get _isLastQuestion {
    if (_phase == _Phase.part1Question) {
      return _currentQIndex >= _totalPart1 - 1;
    }
    if (_phase == _Phase.part3Question) {
      return _currentQIndex >= _totalPart3 - 1;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PART 2 — CUE CARD PREP
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPart2Prep(bool isDark) {
    const color = Color(0xFF2E7D32);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(children: [
        _buildProgressBar(isDark),
        const SizedBox(height: 16),

        // Phase banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.psychology_outlined,
                color: Color(0xFFE65100), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  'Preparation time — plan your answer • ${_fmt(_secsLeft)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65100))),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Cue card
        _buildCueCard(isDark, color),
        const SizedBox(height: 20),

        // Skip prep button
        TextButton(
          onPressed: _startPart2Speaking,
          child: const Text('Skip prep — start speaking now',
              style: TextStyle(fontSize: 13)),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PART 2 — CUE CARD SPEAKING
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPart2Speaking(bool isDark) {
    const color = Color(0xFF2E7D32);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(children: [
        _buildProgressBar(isDark),
        const SizedBox(height: 16),

        // Phase banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(children: [
            Icon(Icons.record_voice_over_rounded,
                color: Color(0xFF2E7D32), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('Speaking — AI is listening...',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32))),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Timer
        _buildTimerRing(isDark, color, kPart2SpeakSecs.toDouble()),
        const SizedBox(height: 16),

        // Live transcript
        if (_fullTranscript.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A2E4A).withOpacity(0.5)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: Text(
                _fullTranscript,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355),
                    height: 1.5,
                    fontStyle: FontStyle.italic),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Cue card (collapsed)
        _buildCueCard(isDark, color),
        const SizedBox(height: 20),

        // Finish early button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _finishPart2Speaking,
            icon: const Icon(Icons.stop_rounded, size: 20),
            label: const Text('Finish Speaking',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANALYZING STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAnalyzing(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  strokeWidth: 5,
                  valueColor: AlwaysStoppedAnimation<Color>(isDark
                      ? const Color(0xFF6A1B9A)
                      : const Color(0xFF8E24AA)),
                ),
              ),
              const Icon(Icons.auto_awesome_rounded,
                  size: 36, color: Color(0xFF8E24AA)),
            ]),
          ),
          const SizedBox(height: 28),
          Text('Evaluating your interview...',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E))),
          const SizedBox(height: 8),
          Text('AI is analyzing all 3 parts',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF8899AA)
                      : const Color(0xFF555577))),
          const SizedBox(height: 6),
          Text('This may take 10-15 seconds',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899))),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ERROR STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFC62828), size: 48),
          const SizedBox(height: 16),
          Text(_error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFFCDD5E0)
                      : const Color(0xFF333355),
                  height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Go Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildProgressBar(bool isDark) {
    final progress = _totalSteps > 0 ? _overallProgress / _totalSteps : 0.0;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Progress',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF8899AA)
                    : const Color(0xFF888899))),
        Text('$_overallProgress / $_totalSteps',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF8899AA)
                    : const Color(0xFF888899))),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor:
              isDark ? const Color(0xFF1A2E4A) : const Color(0xFFEEEEF5),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6A1B9A)),
        ),
      ),
    ]);
  }

  Widget _buildTimerRing(bool isDark, Color color, num maxSecs) {
    final progress = maxSecs > 0 ? _secsLeft / maxSecs : 1.0;
    final isLow = _secsLeft <= 10;
    final tc = isLow ? const Color(0xFFC62828) : color;

    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox(
          width: 130,
          height: 130,
          child: CircularProgressIndicator(
            value: 1,
            strokeWidth: 8,
            valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? const Color(0xFF1A2E4A) : const Color(0xFFEEEEF5)),
          ),
        ),
        SizedBox(
          width: 130,
          height: 130,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 8,
            strokeCap: StrokeCap.round,
            valueColor: AlwaysStoppedAnimation<Color>(tc),
          ),
        ),
        if (_isRecording)
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tc.withOpacity(0.08),
              ),
            ),
          ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_fmt(_secsLeft),
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: tc)),
          if (_isRecording)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.mic_rounded, color: tc, size: 12),
              const SizedBox(width: 3),
              Text('recording',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: tc.withOpacity(0.7))),
            ]),
        ]),
      ]),
    );
  }

  Widget _buildCueCard(bool isDark, Color color) {
    if (_card == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_card!.category,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text('Cue Card',
              style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899),
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Text(_card!.topic,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color:
                    isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E),
                height: 1.4)),
        const SizedBox(height: 12),
        ...List.generate(_card!.prompts.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('•  ',
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(_card!.prompts[i],
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFCDD5E0)
                            : const Color(0xFF333355),
                        height: 1.4)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
