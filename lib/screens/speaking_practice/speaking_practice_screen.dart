import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/speaking_question_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/notification_service.dart';
import '../../widgets/banner_ad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/speaking_practice/speaking_practice_screen.dart
//
// Timed practice for Part 1 (30s/q) or Part 3 (45s/q) questions.
// No AI — just timed speaking like random_practice_screen does for Part 2.
// ─────────────────────────────────────────────────────────────────────────────

const int kPart1SecsPerQ = 30;
const int kPart3SecsPerQ = 45;

enum _Phase { idle, speaking, finished }

class SpeakingPracticeScreen extends StatefulWidget {
  final SpeakingTopic topic;
  final String partLabel; // "Part 1" or "Part 3"
  const SpeakingPracticeScreen({
    super.key,
    required this.topic,
    required this.partLabel,
  });
  @override
  State<SpeakingPracticeScreen> createState() => _SpeakingPracticeScreenState();
}

class _SpeakingPracticeScreenState extends State<SpeakingPracticeScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  int _currentQ = 0;
  int _secsLeft = 0;
  Timer? _timer;

  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool get _isPart1 => widget.partLabel == 'Part 1';
  int get _secsPerQ => _isPart1 ? kPart1SecsPerQ : kPart3SecsPerQ;
  List<String> get _questions => widget.topic.questionTexts;
  Color get _accentColor =>
      _isPart1 ? const Color(0xFF0288D1) : const Color(0xFF6A1B9A);

  @override
  void initState() {
    super.initState();
    _secsLeft = _secsPerQ;
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startSpeaking() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.speaking;
      _secsLeft = _secsPerQ;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secsLeft <= 1) {
        _timer?.cancel();
        HapticFeedback.vibrate();
        _onQuestionDone();
      } else {
        setState(() => _secsLeft--);
      }
    });
  }

  void _onQuestionDone() {
    if (_currentQ < _questions.length - 1) {
      // Move to next question
      setState(() {
        _currentQ++;
        _secsLeft = _secsPerQ;
      });
      _fadeCtrl.forward(from: 0);
      _startTimer();
    } else {
      // All questions done
      _finishPractice();
    }
  }

  void _skipQuestion() {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    _onQuestionDone();
  }

  Future<void> _finishPractice() async {
    _timer?.cancel();
    // Mark topic as practiced
    if (_isPart1) {
      await PrefsRepository.markPart1Practiced(widget.topic.id);
    } else {
      await PrefsRepository.markPart3Practiced(widget.topic.id);
    }
    await PrefsRepository.recordStreakToday();
    await AdService.showInterstitialAfterPractice();
    NotificationService.onPracticeCompleted();
    if (mounted) {
      setState(() => _phase = _Phase.finished);
    }
  }

  void _restart() {
    setState(() {
      _phase = _Phase.idle;
      _currentQ = 0;
      _secsLeft = _secsPerQ;
    });
    _fadeCtrl.forward(from: 0);
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Color _timerColor(bool isDark) {
    if (_phase == _Phase.speaking) {
      return _secsLeft <= 5 ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    }
    return isDark ? const Color(0xFF4DB6FF) : _accentColor;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('${widget.partLabel} Practice'),
        backgroundColor: isDark ? const Color(0xFF0F1B2D) : _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Question counter
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  'Q ${_currentQ + 1}/${_questions.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(children: [
              _buildTopicHeader(isDark),
              const SizedBox(height: 18),
              _buildPhaseBanner(isDark),
              const SizedBox(height: 18),
              _buildTimerRing(isDark),
              const SizedBox(height: 24),
              _buildQuestionCard(isDark),
              const SizedBox(height: 24),
              _buildActions(isDark),
            ]),
          ),
        ),
        const BannerAdWidget(),
      ]),
    );
  }

  Widget _buildTopicHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(
          _isPart1 ? Icons.chat_bubble_outline_rounded : Icons.forum_outlined,
          color: _accentColor,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.partLabel,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                  letterSpacing: 1),
            ),
            Text(
              widget.topic.topic,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPhaseBanner(bool isDark) {
    final String label;
    final IconData icon;
    final Color bg, fg;

    switch (_phase) {
      case _Phase.idle:
        icon = Icons.lightbulb_outline_rounded;
        label = _isPart1
            ? 'Answer each question in ~30 seconds'
            : 'Give extended answers for ~45 seconds each';
        bg = isDark ? const Color(0xFF1A2E4A) : const Color(0xFFE3F2FD);
        fg = isDark ? const Color(0xFF4DB6FF) : _accentColor;
      case _Phase.speaking:
        icon = Icons.mic_rounded;
        label = 'Speak now — Question ${_currentQ + 1} of ${_questions.length}';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
      case _Phase.finished:
        icon = Icons.celebration_rounded;
        label = 'Well done! All ${_questions.length} questions completed ✓';
        bg = const Color(0xFFF3E5F5);
        fg = const Color(0xFF6A1B9A);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: fg))),
      ]),
    );
  }

  Widget _buildTimerRing(bool isDark) {
    final max = _secsPerQ.toDouble();
    final progress = (_phase == _Phase.idle || _phase == _Phase.finished)
        ? 1.0
        : _secsLeft / max;
    final tc = _timerColor(isDark);

    return ScaleTransition(
      scale: (_phase == _Phase.speaking && _secsLeft <= 5)
          ? _pulseAnim
          : const AlwaysStoppedAnimation(1.0),
      child: SizedBox(
          width: 140,
          height: 140,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 10,
                    valueColor: AlwaysStoppedAnimation<Color>(isDark
                        ? const Color(0xFF1A2E4A)
                        : const Color(0xFFEEEEF5)))),
            SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    valueColor: AlwaysStoppedAnimation<Color>(tc))),
            if (_phase == _Phase.idle)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.touch_app_rounded,
                    size: 28,
                    color: isDark ? const Color(0xFF4DB6FF) : _accentColor),
                const SizedBox(height: 4),
                Text('Ready?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? const Color(0xFF4DB6FF) : _accentColor)),
              ])
            else if (_phase == _Phase.finished)
              const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded,
                    size: 36, color: Color(0xFF2E7D32)),
                SizedBox(height: 4),
                Text('Done!',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32))),
              ])
            else
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_fmt(_secsLeft),
                    style: TextStyle(
                        fontSize: 30, fontWeight: FontWeight.bold, color: tc)),
                const SizedBox(height: 2),
                Text('SPEAK',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: tc.withOpacity(0.7))),
              ]),
          ])),
    );
  }

  Widget _buildQuestionCard(bool isDark) {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accentColor.withOpacity(0.22), width: 1.5),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: _accentColor.withOpacity(0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 5))
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'QUESTION ${_currentQ + 1}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _accentColor,
                      letterSpacing: 1.2),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${_secsPerQ}s',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100)),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text(
              _questions[_currentQ],
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E)),
            ),
            if (_phase == _Phase.finished) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('All questions & model answers:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF557799)
                          : const Color(0xFF888899))),
              const SizedBox(height: 8),
              ...List.generate(
                widget.topic.questions.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                                color: _accentColor.withOpacity(0.12),
                                shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _accentColor)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.topic.questions[i].question,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: isDark
                                      ? const Color(0xFFCDD5E0)
                                      : const Color(0xFF333355)),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 32, top: 6),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 14, color: Color(0xFF2E7D32)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.topic.questions[i].sampleAnswer,
                                  style: TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      fontStyle: FontStyle.italic,
                                      color: isDark
                                          ? const Color(0xFFA5D6A7)
                                          : const Color(0xFF2E7D32)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(bool isDark) {
    switch (_phase) {
      case _Phase.idle:
        return Column(children: [
          _PrimaryBtn(
            label: 'Start Speaking',
            icon: Icons.mic_rounded,
            color: _accentColor,
            onTap: _startSpeaking,
          ),
        ]);
      case _Phase.speaking:
        return Column(children: [
          _PrimaryBtn(
            label:
                _currentQ < _questions.length - 1 ? 'Next Question' : 'Finish',
            icon: _currentQ < _questions.length - 1
                ? Icons.skip_next_rounded
                : Icons.check_rounded,
            color: const Color(0xFF2E7D32),
            onTap: _skipQuestion,
          ),
          const SizedBox(height: 10),
          _SecondaryBtn(
            label: 'Stop Practice',
            icon: Icons.stop_rounded,
            isDark: isDark,
            onTap: _finishPractice,
          ),
        ]);
      case _Phase.finished:
        return Column(children: [
          _PrimaryBtn(
            label: 'Practice with AI',
            icon: Icons.psychology_rounded,
            color: const Color(0xFF6A1B9A),
            onTap: () {
              Navigator.pushNamed(context, '/daily-question-practice',
                  arguments: {
                    'question': _questions[0],
                    'partType': widget.partLabel,
                  });
            },
          ),
          const SizedBox(height: 10),
          _PrimaryBtn(
            label: 'Practice Again',
            icon: Icons.replay_rounded,
            color: _accentColor,
            onTap: _restart,
          ),
          const SizedBox(height: 10),
          _SecondaryBtn(
            label: 'Back to Topics',
            icon: Icons.list_rounded,
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),
        ]);
    }
  }
}

// ── Reusable buttons (same pattern as random_practice_screen) ───────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PrimaryBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      );
}

class _SecondaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _SecondaryBtn(
      {required this.label,
      required this.icon,
      required this.isDark,
      required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                isDark ? const Color(0xFF8899AA) : const Color(0xFF555577),
            side: BorderSide(
                color:
                    isDark ? const Color(0xFF2A3E55) : const Color(0xFFDDDDE5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}
