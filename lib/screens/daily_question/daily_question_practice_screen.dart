import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/ad_service.dart';
import '../../widgets/banner_ad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Daily AI Question — Practice Screen
//
// Simpler flow than cue-card AI practice:
//   Show question → user speaks (30s Part 1, 60s Part 3) → AI evaluates.
// No prep timer, no cue card.
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { idle, speaking, analyzing, done }

class DailyQuestionPracticeScreen extends StatefulWidget {
  final String question;
  final String partType; // "Part 1" or "Part 3"

  const DailyQuestionPracticeScreen({
    super.key,
    required this.question,
    required this.partType,
  });

  @override
  State<DailyQuestionPracticeScreen> createState() =>
      _DailyQuestionPracticeScreenState();
}

class _DailyQuestionPracticeScreenState
    extends State<DailyQuestionPracticeScreen> with TickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  late int _maxSecs;
  int _secsLeft = 0;
  Timer? _timer;

  // ── Speech ─────────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  String _transcript = '';
  String _partialText = '';
  int _restartCount = 0;
  bool _isRestarting = false;
  Timer? _safetyTimer;

  // ── Result ─────────────────────────────────────────────────────────────
  AiFeedback? _feedback;
  String? _errorMessage;

  // ── Animations ─────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _maxSecs = widget.partType == 'Part 1' ? 30 : 60;
    _secsLeft = _maxSecs;

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initSpeech();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _safetyTimer?.cancel();
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (_) {
        if (_phase == _Phase.speaking && mounted) _restartListening();
      },
      onStatus: (status) {
        if (status == 'done' && _phase == _Phase.speaking && mounted) {
          _restartListening();
        }
      },
    );
    if (mounted) setState(() {});
  }

  // ── Speaking flow ──────────────────────────────────────────────────────

  void _startSpeaking() {
    if (!PrefsRepository.canUseAi()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(PrefsRepository.isPremium()
            ? 'Daily AI limit reached. Come back tomorrow!'
            : 'Daily limit reached! Upgrade to Premium for more.'),
        action: PrefsRepository.isPremium()
            ? null
            : SnackBarAction(
                label: 'Upgrade',
                onPressed: () => Navigator.pushNamed(context, '/premium')),
      ));
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.speaking;
      _secsLeft = _maxSecs;
      _transcript = '';
      _partialText = '';
    });
    _startTimer();
    _beginListening();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secsLeft <= 1) {
        _timer?.cancel();
        HapticFeedback.vibrate();
        _finishSpeaking();
      } else {
        setState(() => _secsLeft--);
      }
    });
  }

  void _beginListening() {
    if (!_speechAvailable) return;
    _restartCount = 0;
    _isRestarting = false;
    _doListen();
    _safetyTimer?.cancel();
    _safetyTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_phase != _Phase.speaking || !mounted) {
        _safetyTimer?.cancel();
        return;
      }
      if (!_speech.isListening && !_isRestarting) _restartListening();
    });
  }

  void _doListen() {
    if (_phase != _Phase.speaking || !mounted) return;
    _isRestarting = false;
    _speech.listen(
      onResult: _onResult,
      listenFor: const Duration(seconds: 55),
      pauseFor: const Duration(seconds: 30),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  void _restartListening() {
    if (_phase != _Phase.speaking || !_speechAvailable || _isRestarting) return;
    _isRestarting = true;
    _restartCount++;
    if (_restartCount > 20) return;
    _speech.cancel().then((_) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_phase == _Phase.speaking && mounted) _doListen();
      });
    });
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      if (result.finalResult) {
        if (_transcript.isNotEmpty && result.recognizedWords.isNotEmpty) {
          _transcript += ' ';
        }
        _transcript += result.recognizedWords;
        _partialText = '';
        if (_phase == _Phase.speaking) _restartListening();
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

  Future<void> _finishSpeaking() async {
    _timer?.cancel();
    _safetyTimer?.cancel();
    await _speech.stop();

    if (_partialText.isNotEmpty) {
      if (_transcript.isNotEmpty) _transcript += ' ';
      _transcript += _partialText;
      _partialText = '';
    }

    final duration = _maxSecs - _secsLeft;

    if (_transcript.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'No speech detected. Please try again and speak clearly.';
          _phase = _Phase.done;
        });
      }
      return;
    }

    setState(() => _phase = _Phase.analyzing);

    try {
      final feedback = await AiService.evaluateDailyAnswer(
        question: widget.question,
        partType: widget.partType,
        userTranscript: _transcript,
        speakingDurationSecs: duration,
      );

      await PrefsRepository.incrementAiDailyCount();
      await AdService.showVideoAdAfterAiPractice();

      if (mounted) {
        setState(() {
          _feedback = feedback;
          _phase = _Phase.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'AI analysis failed: ${e.toString().length > 200 ? e.toString().substring(0, 200) : e}';
          _phase = _Phase.done;
        });
      }
    }
  }

  void _stopEarly() {
    if (_phase == _Phase.speaking) {
      _finishSpeaking();
    }
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _phase != _Phase.speaking && _phase != _Phase.analyzing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _Phase.speaking) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Stop Recording?'),
              content:
                  const Text('Your progress will be lost if you go back.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Continue')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _timer?.cancel();
                      _safetyTimer?.cancel();
                      _speech.stop();
                      Navigator.pop(context);
                    },
                    child: const Text('Stop & Exit')),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: Text('Daily ${widget.partType} Practice'),
          backgroundColor:
              isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildContent(isDark),
              ),
            ),
            const BannerAdWidget(),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    switch (_phase) {
      case _Phase.idle:
        return _buildIdle(isDark);
      case _Phase.speaking:
        return _buildSpeaking(isDark);
      case _Phase.analyzing:
        return _buildAnalyzing(isDark);
      case _Phase.done:
        return _buildDone(isDark);
    }
  }

  // ── Idle: show question + start button ─────────────────────────────────

  Widget _buildIdle(bool isDark) {
    return Column(
      children: [
        const Spacer(),
        // Part badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF4DB6FF).withOpacity(0.15)
                : const Color(0xFF1565C0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(widget.partType,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFF4DB6FF)
                      : const Color(0xFF1565C0))),
        ),
        const SizedBox(height: 20),
        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: Column(children: [
            Icon(Icons.psychology_rounded,
                size: 40,
                color: isDark
                    ? const Color(0xFF4DB6FF)
                    : const Color(0xFF1565C0)),
            const SizedBox(height: 16),
            Text(widget.question,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E))),
            const SizedBox(height: 16),
            Text(
              widget.partType == 'Part 1'
                  ? 'Answer naturally in 2-4 sentences (30 seconds)'
                  : 'Give an analytical answer with examples (60 seconds)',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899)),
            ),
          ]),
        ),
        const SizedBox(height: 32),
        // Start button
        GestureDetector(
          onTap: _startSpeaking,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child:
                const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text('Tap to start speaking',
            style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF557799)
                    : const Color(0xFF888899))),
        const Spacer(),
        // Remaining credits
        Text(
          'AI practices remaining today: ${PrefsRepository.getAiRemaining()}',
          style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? const Color(0xFF446688)
                  : const Color(0xFF999999)),
        ),
      ],
    );
  }

  // ── Speaking: timer + waveform ─────────────────────────────────────────

  Widget _buildSpeaking(bool isDark) {
    final timerColor = _secsLeft <= 10
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);

    return Column(
      children: [
        const SizedBox(height: 20),
        // Timer
        Text(_fmt(_secsLeft),
            style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: timerColor,
                letterSpacing: 2)),
        const SizedBox(height: 8),
        Text('Speak now...',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF4DB6FF)
                    : const Color(0xFF1565C0))),
        const SizedBox(height: 24),
        // Question reminder
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A2E4A).withOpacity(0.6)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(widget.question,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFCDD5E0)
                      : const Color(0xFF333355))),
        ),
        const SizedBox(height: 24),
        // Animated mic
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC62828).withOpacity(0.12),
              ),
              child: const Icon(Icons.mic_rounded,
                  color: Color(0xFFC62828), size: 32),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Live transcript
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _fullTranscript.isEmpty
                    ? 'Your words will appear here...'
                    : _fullTranscript,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  fontStyle: _fullTranscript.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: _fullTranscript.isEmpty
                      ? (isDark
                          ? const Color(0xFF446688)
                          : const Color(0xFFAAAAAA))
                      : (isDark
                          ? const Color(0xFFCDD5E0)
                          : const Color(0xFF333355)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Stop button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _stopEarly,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Finish & Get Score'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Analyzing ──────────────────────────────────────────────────────────

  Widget _buildAnalyzing(bool isDark) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color:
                isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 20),
        Text('AI is evaluating your answer...',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E))),
        const SizedBox(height: 8),
        Text('This may take a few seconds',
            style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF557799)
                    : const Color(0xFF888899))),
      ]),
    );
  }

  // ── Done: show results inline ──────────────────────────────────────────

  Widget _buildDone(bool isDark) {
    if (_errorMessage != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFC62828), size: 48),
          const SizedBox(height: 16),
          Text(_errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFFCDD5E0)
                      : const Color(0xFF333355))),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back')),
        ]),
      );
    }

    final f = _feedback!;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Band Score Header ──────────────────────────────────────────
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _bandColor(f.overallBand),
                _bandColor(f.overallBand).withOpacity(0.8),
              ]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              const Text('Your Band Score',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(f.overallBand.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.bold)),
              Text(_bandLabel(f.overallBand),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // ── Band Breakdown ────────────────────────────────────────────
        _buildCard(isDark, children: [
          _bandRow('Fluency & Coherence', f.fluencyBand, isDark),
          const SizedBox(height: 10),
          _bandRow('Lexical Resource', f.lexicalBand, isDark),
          const SizedBox(height: 10),
          _bandRow('Grammar', f.grammarBand, isDark),
          const SizedBox(height: 10),
          _bandRow('Pronunciation*', f.pronunciationBand, isDark),
        ]),
        const SizedBox(height: 14),

        // ── AI Comment ────────────────────────────────────────────────
        _buildCard(isDark, children: [
          _sectionTitle('AI Assessment', Icons.comment_rounded,
              const Color(0xFF1565C0), isDark),
          const SizedBox(height: 10),
          Text(f.overallComment,
              style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: isDark
                      ? const Color(0xFFCDD5E0)
                      : const Color(0xFF333355))),
        ]),
        const SizedBox(height: 14),

        // ── Strengths ─────────────────────────────────────────────────
        if (f.strengths.isNotEmpty) ...[
          _buildCard(isDark, children: [
            _sectionTitle('Strengths', Icons.thumb_up_rounded,
                const Color(0xFF2E7D32), isDark),
            const SizedBox(height: 10),
            ...f.strengths.map((s) => _bullet(s, const Color(0xFF2E7D32), isDark)),
          ]),
          const SizedBox(height: 14),
        ],

        // ── Improvements ──────────────────────────────────────────────
        if (f.improvements.isNotEmpty) ...[
          _buildCard(isDark, children: [
            _sectionTitle('Areas to Improve', Icons.trending_up_rounded,
                const Color(0xFFE65100), isDark),
            const SizedBox(height: 10),
            ...f.improvements.map(
                (s) => _bullet(s, const Color(0xFFE65100), isDark)),
          ]),
          const SizedBox(height: 14),
        ],

        // ── Improved Answer ───────────────────────────────────────────
        if (f.improvedAnswer.isNotEmpty) ...[
          _buildCard(isDark, children: [
            _sectionTitle('Improved Version', Icons.auto_fix_high_rounded,
                const Color(0xFF6A1B9A), isDark),
            const SizedBox(height: 10),
            Text(f.improvedAnswer,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355))),
          ]),
          const SizedBox(height: 14),
        ],

        // ── Your Transcript (with highlights) ─────────────────────────
        _buildCard(isDark, children: [
          _sectionTitle(
              'Your Response',
              Icons.record_voice_over_rounded,
              isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0),
              isDark),
          const SizedBox(height: 10),
          _buildHighlightedTranscript(isDark, f),
          if (f.pronunciationFlags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE65100).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                      color: const Color(0xFFE65100).withOpacity(0.5)),
                ),
              ),
              const SizedBox(width: 6),
              Text('Pronunciation practice needed',
                  style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? const Color(0xFF446688)
                          : const Color(0xFF999999))),
            ]),
          ],
        ]),
        const SizedBox(height: 24),

        // ── Action Buttons ────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _buildCard(bool isDark, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _sectionTitle(
      String title, IconData icon, Color color, bool isDark) {
    return Row(children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, color: color, size: 15),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? const Color(0xFFE8EAF0)
                  : const Color(0xFF1A1A2E))),
    ]);
  }

  Widget _bandRow(String label, double band, bool isDark) {
    final color = _bandColor(band);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF8899AA)
                        : const Color(0xFF555577)))),
        Text(band.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: band / 9.0,
          minHeight: 5,
          backgroundColor:
              isDark ? const Color(0xFF0F1B2D) : const Color(0xFFEEEEF5),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }

  Widget _bullet(String text, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355)))),
      ]),
    );
  }

  Widget _buildHighlightedTranscript(bool isDark, AiFeedback f) {
    if (f.pronunciationFlags.isEmpty) {
      return Text(_transcript,
          style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: isDark
                  ? const Color(0xFF8899AA)
                  : const Color(0xFF555577)));
    }

    final flagged = f.pronunciationFlags.map((w) => w.toLowerCase()).toSet();
    final pattern = RegExp(r"(\b\w+\b)");
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(_transcript)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: _transcript.substring(lastEnd, match.start)));
      }
      final word = match.group(0)!;
      if (flagged.contains(word.toLowerCase())) {
        spans.add(TextSpan(
          text: word,
          style: TextStyle(
            backgroundColor:
                const Color(0xFFE65100).withOpacity(isDark ? 0.2 : 0.12),
            color: isDark ? const Color(0xFFFF8A65) : const Color(0xFFE65100),
            fontWeight: FontWeight.w600,
          ),
        ));
      } else {
        spans.add(TextSpan(text: word));
      }
      lastEnd = match.end;
    }
    if (lastEnd < _transcript.length) {
      spans.add(TextSpan(text: _transcript.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          height: 1.6,
          color: isDark ? const Color(0xFF8899AA) : const Color(0xFF555577),
        ),
        children: spans,
      ),
    );
  }

  static Color _bandColor(double band) {
    if (band >= 7.5) return const Color(0xFF2E7D32);
    if (band >= 6.5) return const Color(0xFF1565C0);
    if (band >= 5.5) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  static String _bandLabel(double band) {
    if (band >= 8.0) return 'Expert User';
    if (band >= 7.0) return 'Good User';
    if (band >= 6.0) return 'Competent User';
    if (band >= 5.0) return 'Modest User';
    if (band >= 4.0) return 'Limited User';
    return 'Keep Practicing!';
  }
}
