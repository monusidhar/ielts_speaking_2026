import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../data/repositories/practice_history_repository.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/review_service.dart';
import '../../data/services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/practice/ai_practice_screen.dart
//
// AI Speaking Coach — Records speech via mic, transcribes, sends to Gemini
// for IELTS band scoring and detailed feedback. Premium-only feature.
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Color> _catColors = {
  'Travel': Color(0xFF0288D1),
  'Education': Color(0xFF2E7D32),
  'Personal': Color(0xFF6A1B9A),
  'People': Color(0xFFE65100),
  'Arts': Color(0xFFC62828),
  'Society': Color(0xFF37474F),
  'Culture': Color(0xFF00695C),
  'Technology': Color(0xFF1565C0),
  'Sports': Color(0xFF558B2F),
  'Work': Color(0xFF4E342E),
  'Food': Color(0xFFEF6C00),
  'Nature': Color(0xFF1B5E20),
};
Color _catColor(String cat) => _catColors[cat] ?? const Color(0xFF1565C0);

const int kAiPrepSeconds = 60;
const int kAiSpeakSeconds = 120;

enum _AiPhase { idle, prep, speaking, analyzing, finished }

class AiPracticeScreen extends StatefulWidget {
  const AiPracticeScreen({super.key});
  @override
  State<AiPracticeScreen> createState() => _AiPracticeScreenState();
}

class _AiPracticeScreenState extends State<AiPracticeScreen>
    with TickerProviderStateMixin {
  CueCard? _card;
  bool _isLoading = true;
  _AiPhase _phase = _AiPhase.idle;
  int _secsLeft = kAiPrepSeconds;
  Timer? _timer;

  // ── Speech recognition ────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String _transcript = '';
  String _partialText = '';
  double _soundLevel = 0.0;
  int _restartCount = 0;
  bool _isRestarting = false;
  Timer? _safetyTimer;

  // ── AI Feedback ───────────────────────────────────────────────────────────
  AiFeedback? _feedback;
  String? _errorMessage;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _micPulseCtrl;
  late Animation<double> _micPulseAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _micPulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _micPulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _micPulseCtrl, curve: Curves.easeInOut));

    _initSpeech();
    _loadRandom();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _safetyTimer?.cancel();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _micPulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (error) {
        // Any error during speaking phase → try to restart
        if (_phase == _AiPhase.speaking && mounted) {
          _restartListening();
        }
      },
      onStatus: (status) {
        // Auto-restart listening if it stops during speaking phase
        if (status == 'done' && _phase == _AiPhase.speaking && mounted) {
          _restartListening();
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _loadRandom() async {
    setState(() => _isLoading = true);
    try {
      final card = PrefsRepository.isPremium()
          ? await CueCardRepository.getRandom()
          : await CueCardRepository.getRandomFree();
      if (mounted) {
        setState(() {
          _card = card;
          _phase = _AiPhase.idle;
          _secsLeft = kAiPrepSeconds;
          _transcript = '';
          _partialText = '';
          _feedback = null;
          _errorMessage = null;
          _isLoading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Phase transitions ──────────────────────────────────────────────────────

  void _startPrep() {
    if (!PrefsRepository.canUseAi()) {
      setState(() {
        _phase = _AiPhase.idle;
      });
      return; // limit-reached UI will show via _buildActions
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _AiPhase.prep;
      _secsLeft = kAiPrepSeconds;
    });
    _startTimer();
  }

  void _startSpeaking() {
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _AiPhase.speaking;
      _secsLeft = kAiSpeakSeconds;
      _transcript = '';
      _partialText = '';
    });
    _startTimer();
    _startListening();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secsLeft <= 1) {
        _timer?.cancel();
        HapticFeedback.vibrate();
        if (_phase == _AiPhase.prep) {
          _startSpeaking();
        } else if (_phase == _AiPhase.speaking) {
          _finishSpeaking();
        }
      } else {
        setState(() => _secsLeft--);
      }
    });
  }

  // ── Speech recognition ────────────────────────────────────────────────────

  void _startListening() {
    if (!_speechAvailable) return;
    _restartCount = 0;
    _isRestarting = false;
    _doListen();
    // Safety-net: every 3s check if speech died silently
    _safetyTimer?.cancel();
    _safetyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_phase != _AiPhase.speaking || !mounted) {
        _safetyTimer?.cancel();
        return;
      }
      if (!_speech.isListening && !_isRestarting) {
        _restartListening();
      }
    });
  }

  void _doListen() {
    if (_phase != _AiPhase.speaking || !mounted) return;
    _isRestarting = false;
    _speech.listen(
      onResult: _onSpeechResult,
      onSoundLevelChange: (level) {
        _soundLevel = level;
      },
      listenFor: const Duration(seconds: 55),
      pauseFor: const Duration(seconds: 30),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  void _restartListening() {
    if (_phase != _AiPhase.speaking || !_speechAvailable || _isRestarting)
      return;
    _isRestarting = true;
    _restartCount++;
    if (_restartCount > 30) return; // generous limit for 2 min
    _speech.cancel().then((_) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_phase == _AiPhase.speaking && mounted) {
          _doListen();
        }
      });
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      if (result.finalResult) {
        if (_transcript.isNotEmpty && result.recognizedWords.isNotEmpty) {
          _transcript += ' ';
        }
        _transcript += result.recognizedWords;
        _partialText = '';
        // Restart after final result
        if (_phase == _AiPhase.speaking) {
          _restartListening();
        }
      } else {
        _partialText = result.recognizedWords;
      }
    });
  }

  String get _fullTranscript {
    if (_partialText.isEmpty) return _transcript;
    if (_transcript.isEmpty) return _partialText;
    return '$_transcript $_partialText';
  }

  // ── Finish & Analyze ──────────────────────────────────────────────────────

  Future<void> _finishSpeaking() async {
    _timer?.cancel();
    _safetyTimer?.cancel();
    await _speech.stop();

    // Include any partial text in the final transcript
    if (_partialText.isNotEmpty) {
      if (_transcript.isNotEmpty) _transcript += ' ';
      _transcript += _partialText;
      _partialText = '';
    }

    final actualDuration = kAiSpeakSeconds - _secsLeft;

    if (_transcript.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'No speech detected. Please try again and speak clearly into your microphone.';
          _phase = _AiPhase.finished;
        });
      }
      return;
    }

    setState(() => _phase = _AiPhase.analyzing);

    try {
      if (!AiService.isConfigured) {
        throw Exception('AI service not configured. Please contact support.');
      }

      if (!PrefsRepository.canUseAi()) {
        throw Exception(PrefsRepository.isPremium()
            ? 'Daily limit reached! You can do ${PrefsRepository.aiDailyLimit} AI practices per day. Come back tomorrow for more.'
            : 'Daily limit reached! Free members get 5 AI practices per day. Buy Premium for 15 daily practices!');
      }

      final feedback = await AiService.evaluateAnswer(
        topic: _card!.topic,
        prompts: _card!.prompts,
        userTranscript: _transcript,
        sampleAnswer: _card!.bandAnswer,
        speakingDurationSecs: actualDuration,
      );

      // Save to history
      final session = PracticeSession.fromFeedback(
        cardId: _card!.id,
        topic: _card!.topic,
        category: _card!.category,
        feedback: feedback,
        transcript: _transcript,
        durationSecs: actualDuration,
      );
      await PracticeHistoryRepository.addSession(session);

      // Mark card as practiced & increment daily AI counter
      await PrefsRepository.markPracticed(_card!.id);
      await PrefsRepository.incrementAiDailyCount();
      await PrefsRepository.recordStreakToday();
      await AdService.showVideoAdAfterAiPractice();
      ReviewService.maybeRequestReview(feedback.overallBand);
      NotificationService.onPracticeCompleted();

      if (mounted) {
        setState(() {
          _feedback = feedback;
          _phase = _AiPhase.finished;
        });
      }
    } catch (e) {
      debugPrint('AI analysis failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'AI analysis failed: ${e.toString().length > 200 ? e.toString().substring(0, 200) : e.toString()}';
          _phase = _AiPhase.finished;
        });
      }
    }
  }

  void _stopEarly() {
    if (_phase == _AiPhase.speaking) {
      _finishSpeaking();
    } else {
      _timer?.cancel();
      _safetyTimer?.cancel();
      _speech.stop();
      setState(() {
        _phase = _AiPhase.idle;
        _secsLeft = kAiPrepSeconds;
      });
    }
  }

  void _nextCard() {
    _timer?.cancel();
    _safetyTimer?.cancel();
    _speech.stop();
    _loadRandom();
  }

  void _viewFeedback() {
    if (_feedback != null && _card != null) {
      Navigator.pushNamed(context, '/ai-feedback', arguments: {
        'feedback': _feedback,
        'card': _card,
        'transcript': _transcript,
      });
    }
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Color _timerColor(bool isDark) {
    if (_phase == _AiPhase.prep)
      return _secsLeft <= 10
          ? const Color(0xFFE65100)
          : const Color(0xFFFFB300);
    if (_phase == _AiPhase.speaking)
      return _secsLeft <= 20
          ? const Color(0xFFC62828)
          : const Color(0xFF2E7D32);
    return isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color =
        _card != null ? _catColor(_card!.category) : const Color(0xFF1565C0);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('AI Speaking Coach'),
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Daily remaining counter
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                      '${PrefsRepository.getAiRemaining()}/${PrefsRepository.aiDailyLimit} left',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
          // History button
          IconButton(
            icon: const Icon(Icons.history_rounded, size: 22),
            tooltip: 'Practice History',
            onPressed: () => Navigator.pushNamed(context, '/practice-history'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: isDark
                      ? const Color(0xFF4DB6FF)
                      : const Color(0xFF1565C0)))
          : _card == null
              ? _buildError(isDark)
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(children: [
                    _buildPremiumBadge(isDark),
                    const SizedBox(height: 12),
                    _buildPhaseBanner(isDark),
                    const SizedBox(height: 18),
                    if (_phase == _AiPhase.analyzing)
                      _buildAnalyzingState(isDark)
                    else ...[
                      _buildTimerRing(isDark),
                      const SizedBox(height: 16),
                    ],
                    if (_phase == _AiPhase.speaking ||
                        (_phase == _AiPhase.finished && _transcript.isNotEmpty))
                      _buildTranscriptBox(isDark),
                    if (_phase == _AiPhase.finished && _feedback != null)
                      _buildQuickResults(isDark),
                    if (_phase == _AiPhase.finished && _errorMessage != null)
                      _buildErrorBox(isDark),
                    const SizedBox(height: 16),
                    _buildCard(isDark, color),
                    const SizedBox(height: 24),
                    _buildActions(isDark, color),
                    const SizedBox(height: 14),
                    _buildSecondaryActions(isDark),
                  ]),
                ),
    );
  }

  Widget _buildPremiumBadge(bool isDark) {
    final isPremium = PrefsRepository.isPremium();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFFFFB300), const Color(0xFFFF8F00)]
              : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isPremium ? Icons.auto_awesome_rounded : Icons.stars_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Text(
            isPremium
                ? 'AI-Powered  •  Premium Member'
                : 'AI-Powered  •  Free (5/day)',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ]),
    );
  }

  Widget _buildPhaseBanner(bool isDark) {
    final configs = {
      _AiPhase.idle: _BannerCfg(
          icon: Icons.mic_rounded,
          label: 'Read the card, then speak — AI will grade you',
          bg: isDark ? const Color(0xFF1A2E4A) : const Color(0xFFE3F2FD),
          fg: isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0)),
      _AiPhase.prep: _BannerCfg(
          icon: Icons.psychology_outlined,
          label: 'Preparation time — plan your answer',
          bg: const Color(0xFFFFF8E1),
          fg: const Color(0xFFE65100)),
      _AiPhase.speaking: _BannerCfg(
          icon: Icons.record_voice_over_rounded,
          label: 'Speaking — AI is listening...',
          bg: const Color(0xFFE8F5E9),
          fg: const Color(0xFF2E7D32)),
      _AiPhase.analyzing: _BannerCfg(
          icon: Icons.auto_awesome_rounded,
          label: 'Analyzing your response with AI...',
          bg: const Color(0xFFF3E5F5),
          fg: const Color(0xFF6A1B9A)),
      _AiPhase.finished: _BannerCfg(
          icon: Icons.check_circle_rounded,
          label: _feedback != null
              ? 'Band ${_feedback!.overallBand.toStringAsFixed(1)} — Tap "View Feedback" for details'
              : _errorMessage != null
                  ? 'Could not analyze — see details below'
                  : 'Done!',
          bg: _feedback != null
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFF8E1),
          fg: _feedback != null
              ? const Color(0xFF2E7D32)
              : const Color(0xFFE65100)),
    };
    final c = configs[_phase]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration:
          BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(c.icon, color: c.fg, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(c.label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: c.fg))),
      ]),
    );
  }

  Widget _buildAnalyzingState(bool isDark) {
    return Column(children: [
      const SizedBox(height: 20),
      SizedBox(
        width: 120,
        height: 120,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF6A1B9A) : const Color(0xFF8E24AA)),
            ),
          ),
          const Icon(Icons.auto_awesome_rounded,
              size: 40, color: Color(0xFF8E24AA)),
        ]),
      ),
      const SizedBox(height: 20),
      Text('AI is evaluating your response...',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color:
                  isDark ? const Color(0xFFCDD5E0) : const Color(0xFF333355))),
      const SizedBox(height: 8),
      Text('This may take a few seconds',
          style: TextStyle(
              fontSize: 12,
              color:
                  isDark ? const Color(0xFF557799) : const Color(0xFF888899))),
      const SizedBox(height: 24),
    ]);
  }

  Widget _buildTimerRing(bool isDark) {
    final max = _phase == _AiPhase.prep
        ? kAiPrepSeconds.toDouble()
        : kAiSpeakSeconds.toDouble();
    final progress = (_phase == _AiPhase.idle || _phase == _AiPhase.finished)
        ? 1.0
        : _secsLeft / max;
    final tc = _timerColor(isDark);

    final showMicPulse = _phase == _AiPhase.speaking;

    return ScaleTransition(
      scale: (_phase == _AiPhase.speaking && _secsLeft <= 10)
          ? _pulseAnim
          : const AlwaysStoppedAnimation(1.0),
      child: SizedBox(
          width: 160,
          height: 160,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 10,
                    valueColor: AlwaysStoppedAnimation<Color>(isDark
                        ? const Color(0xFF1A2E4A)
                        : const Color(0xFFEEEEF5)))),
            SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(tc))),
            // Sound level ring when speaking
            if (showMicPulse)
              ScaleTransition(
                scale: _micPulseAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        tc.withOpacity(0.08 + (_soundLevel.clamp(0, 10) / 100)),
                  ),
                ),
              ),
            if (_phase == _AiPhase.idle)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mic_rounded,
                    size: 32,
                    color: isDark
                        ? const Color(0xFF4DB6FF)
                        : const Color(0xFF1565C0)),
                const SizedBox(height: 4),
                Text('AI Coach',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF4DB6FF)
                            : const Color(0xFF1565C0))),
              ])
            else if (_phase == _AiPhase.finished && _feedback != null)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_feedback!.overallBand.toStringAsFixed(1),
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _bandColor(_feedback!.overallBand))),
                const SizedBox(height: 2),
                Text('BAND',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: _bandColor(_feedback!.overallBand)
                            .withOpacity(0.7))),
              ])
            else if (_phase == _AiPhase.finished)
              const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded, size: 36, color: Color(0xFFE65100)),
                SizedBox(height: 4),
                Text('Try Again',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100))),
              ])
            else
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_fmt(_secsLeft),
                    style: TextStyle(
                        fontSize: 34, fontWeight: FontWeight.bold, color: tc)),
                const SizedBox(height: 2),
                Text(_phase == _AiPhase.prep ? 'PREP' : 'SPEAK',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: tc.withOpacity(0.7))),
                if (_phase == _AiPhase.speaking) ...[
                  const SizedBox(height: 4),
                  Icon(Icons.mic_rounded, size: 16, color: tc.withOpacity(0.6)),
                ],
              ]),
          ])),
    );
  }

  Widget _buildTranscriptBox(bool isDark) {
    final text = _fullTranscript;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _phase == _AiPhase.speaking
              ? const Color(0xFF2E7D32).withOpacity(0.4)
              : (isDark ? const Color(0xFF2A3E55) : const Color(0xFFDDDDEE)),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              _phase == _AiPhase.speaking
                  ? Icons.mic_rounded
                  : Icons.text_snippet_outlined,
              size: 16,
              color: _phase == _AiPhase.speaking
                  ? const Color(0xFF2E7D32)
                  : (isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899))),
          const SizedBox(width: 6),
          Text(
              _phase == _AiPhase.speaking ? 'Live Transcript' : 'Your Response',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: _phase == _AiPhase.speaking
                      ? const Color(0xFF2E7D32)
                      : (isDark
                          ? const Color(0xFF557799)
                          : const Color(0xFF888899)))),
          const Spacer(),
          Text('${text.split(' ').where((w) => w.isNotEmpty).length} words',
              style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899))),
        ]),
        const SizedBox(height: 10),
        Text(text.isEmpty ? 'Listening...' : text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: text.isEmpty
                  ? (isDark ? const Color(0xFF446688) : const Color(0xFFAAAAAA))
                  : (isDark
                      ? const Color(0xFFCDD5E0)
                      : const Color(0xFF333355)),
              fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal,
            )),
      ]),
    );
  }

  Widget _buildQuickResults(bool isDark) {
    final f = _feedback!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bandColor(f.overallBand).withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _bandColor(f.overallBand).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded,
                  size: 18, color: Color(0xFFFFB300)),
              const SizedBox(width: 4),
              Text('Band ${f.overallBand.toStringAsFixed(1)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _bandColor(f.overallBand))),
            ]),
          ),
          const Spacer(),
          Text('AI Assessment',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899))),
        ]),
        const SizedBox(height: 14),
        // Band breakdown row
        Row(children: [
          _MiniScore(label: 'Fluency', band: f.fluencyBand, isDark: isDark),
          _MiniScore(label: 'Lexical', band: f.lexicalBand, isDark: isDark),
          _MiniScore(label: 'Grammar', band: f.grammarBand, isDark: isDark),
          _MiniScore(
              label: 'Pronun.', band: f.pronunciationBand, isDark: isDark),
        ]),
        const SizedBox(height: 14),
        Text(f.overallComment,
            style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? const Color(0xFFCDD5E0)
                    : const Color(0xFF333355))),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _viewFeedback,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('View Full Feedback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildErrorBox(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFC62828).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC62828).withOpacity(0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded,
            size: 20, color: Color(0xFFC62828)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(_errorMessage ?? 'An error occurred',
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: Color(0xFFC62828)))),
      ]),
    );
  }

  Widget _buildLimitReachedBox(bool isDark) {
    final isPremium = PrefsRepository.isPremium();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFFFF8F00).withOpacity(0.3), width: 1.5),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: const Color(0xFFFF8F00).withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_clock_rounded,
              color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        Text('Daily Limit Reached',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        Text(
          isPremium
              ? 'You\u2019ve used all 15 AI practices for today.\nCome back tomorrow for more!'
              : 'As a free member, you get 5 AI practices per day.\nUpgrade to Premium for 15 daily practices!',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color:
                  isDark ? const Color(0xFF8899AA) : const Color(0xFF555577)),
        ),
        if (!isPremium) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/premium'),
              icon: const Icon(Icons.workspace_premium_rounded, size: 20),
              label: const Text('Upgrade to Premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                elevation: 3,
                shadowColor: const Color(0xFFFF8F00).withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8F00).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Color(0xFFFF8F00)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                'Premium: 15 AI practices/day + all 200+ cue cards',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFE65100)),
              )),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Resets at midnight',
          style: TextStyle(
              fontSize: 11,
              color:
                  isDark ? const Color(0xFF557799) : const Color(0xFF888899)),
        ),
      ]),
    );
  }

  Widget _buildCard(bool isDark, Color color) {
    final card = _card!;
    return FadeTransition(
      opacity: _fadeCtrl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.22), width: 1.5),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: color.withOpacity(0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 5))
                ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(card.category.toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 1.2)),
            ),
            const Spacer(),
            Text('Card #${card.id}',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF557799)
                        : const Color(0xFF888899))),
          ]),
          const SizedBox(height: 14),
          Text(card.topic,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  height: 1.38,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E))),
          const SizedBox(height: 14),
          Text('You should say:',
              style: TextStyle(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899))),
          const SizedBox(height: 10),
          ...List.generate(
              card.prompts.length,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: color))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(card.prompts[i],
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.45,
                                      color: isDark
                                          ? const Color(0xFFCDD5E0)
                                          : const Color(0xFF333355)))),
                        ]),
                  )),
        ]),
      ),
    );
  }

  Widget _buildActions(bool isDark, Color color) {
    switch (_phase) {
      case _AiPhase.idle:
        // Check if daily limit reached
        if (!PrefsRepository.canUseAi()) {
          return _buildLimitReachedBox(isDark);
        }
        return Column(children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !_speechAvailable ? null : _startPrep,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(_speechAvailable
                  ? 'Start Practice (1 min prep)'
                  : 'Mic not available'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                elevation: 3,
                shadowColor: const Color(0xFF1565C0).withOpacity(0.4),
              ),
            ),
          ),
          if (!_speechAvailable) ...[
            const SizedBox(height: 8),
            Text('Please grant microphone permission to use AI Coach',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF557799)
                        : const Color(0xFF888899))),
          ],
        ]);
      case _AiPhase.prep:
        return Column(children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startSpeaking,
              icon: const Icon(Icons.mic_rounded, size: 20),
              label: const Text('Start Speaking Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildSecBtn('Stop', Icons.stop_rounded, isDark, _stopEarly),
        ]);
      case _AiPhase.speaking:
        return Column(children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _stopEarly,
              icon: const Icon(Icons.stop_rounded, size: 20),
              label: const Text('Finish & Get AI Feedback'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]);
      case _AiPhase.analyzing:
        return const SizedBox.shrink();
      case _AiPhase.finished:
        return Column(children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _nextCard,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: const Text('Next Card'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]);
    }
  }

  Widget _buildSecondaryActions(bool isDark) {
    if (_phase == _AiPhase.analyzing) return const SizedBox.shrink();
    return Row(children: [
      Expanded(
          child: _buildSecBtn(
              'Skip Card', Icons.skip_next_rounded, isDark, _nextCard)),
      const SizedBox(width: 12),
      Expanded(
          child: _buildSecBtn(
              'View Answer',
              Icons.visibility_outlined,
              isDark,
              () => Navigator.pushNamed(context, '/cue-card-detail',
                  arguments: {'cardId': _card?.id ?? 1}))),
    ]);
  }

  Widget _buildSecBtn(
      String label, IconData icon, bool isDark, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDark ? const Color(0xFF8899AA) : const Color(0xFF555577),
          side: BorderSide(
              color:
                  isDark ? const Color(0xFF2A3E55) : const Color(0xFFDDDDEE)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildError(bool isDark) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded,
            size: 48, color: Color(0xFFC62828)),
        const SizedBox(height: 12),
        Text('Could not load cards',
            style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF8899AA)
                    : const Color(0xFF555577))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            onPressed: _loadRandom,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry')),
      ]));

  static Color _bandColor(double band) {
    if (band >= 7.5) return const Color(0xFF2E7D32);
    if (band >= 6.5) return const Color(0xFF1565C0);
    if (band >= 5.5) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }
}

class _MiniScore extends StatelessWidget {
  final String label;
  final double band;
  final bool isDark;
  const _MiniScore(
      {required this.label, required this.band, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Column(children: [
      Text(band.toStringAsFixed(1),
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _AiPracticeScreenState._bandColor(band))),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color:
                  isDark ? const Color(0xFF557799) : const Color(0xFF888899))),
    ]));
  }
}

class _BannerCfg {
  final IconData icon;
  final String label;
  final Color bg, fg;
  const _BannerCfg(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.fg});
}
