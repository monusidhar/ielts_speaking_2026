import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/notification_service.dart';
import '../../widgets/banner_ad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/random_practice/random_practice_screen.dart
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

const int kPrepSeconds = 60;
const int kSpeakSeconds = 120;

enum _Phase { idle, prep, speaking, finished }

class RandomPracticeScreen extends StatefulWidget {
  const RandomPracticeScreen({super.key});
  @override
  State<RandomPracticeScreen> createState() => _RandomPracticeScreenState();
}

class _RandomPracticeScreenState extends State<RandomPracticeScreen>
    with TickerProviderStateMixin {
  CueCard? _card;
  bool _isLoading = true;
  _Phase _phase = _Phase.idle;
  int _secsLeft = kPrepSeconds;
  int _sessionCount = 0;
  Timer? _timer;

  late AnimationController _fadeCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

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

    _sessionCount = PrefsRepository.getPracticedTotal();
    _loadRandom();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Load a random card ─────────────────────────────────────────────────────
  // Free users  → random from cards 1–kFreeCardLimit only
  // Premium     → random from all cards
  Future<void> _loadRandom() async {
    setState(() => _isLoading = true);
    try {
      CueCard card;
      if (PrefsRepository.isPremium()) {
        // Premium: pick from the full deck
        card = await CueCardRepository.getRandom();
      } else {
        // Free: pick only from the first 50 cards
        card = await CueCardRepository.getRandomFree();
      }

      if (mounted) {
        setState(() {
          _card = card;
          _phase = _Phase.idle;
          _secsLeft = kPrepSeconds;
          _isLoading = false;
        });
        _fadeCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startPrep() {
    HapticFeedback.mediumImpact();
    setState(() {
      _phase = _Phase.prep;
      _secsLeft = kPrepSeconds;
    });
    _startTimer();
  }

  void _startSpeaking() {
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _Phase.speaking;
      _secsLeft = kSpeakSeconds;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secsLeft <= 1) {
        _timer?.cancel();
        HapticFeedback.vibrate();
        if (_phase == _Phase.prep) {
          _startSpeaking();
        } else if (_phase == _Phase.speaking) {
          _finishCard();
        }
      } else {
        setState(() => _secsLeft--);
      }
    });
  }

  Future<void> _finishCard() async {
    if (_card != null) {
      await PrefsRepository.markPracticed(_card!.id);
    }
    await PrefsRepository.recordStreakToday();
    await AdService.showInterstitialAfterPractice();
    NotificationService.onPracticeCompleted();

    if (mounted) {
      setState(() {
        _phase = _Phase.finished;
        _sessionCount = PrefsRepository.getPracticedTotal();
      });
    }
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.idle;
      _secsLeft = kPrepSeconds;
    });
  }

  void _nextCard() {
    _timer?.cancel();
    _loadRandom();
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Color _timerColor(bool isDark) {
    if (_phase == _Phase.prep)
      return _secsLeft <= 10
          ? const Color(0xFFE65100)
          : const Color(0xFFFFB300);
    if (_phase == _Phase.speaking)
      return _secsLeft <= 20
          ? const Color(0xFFC62828)
          : const Color(0xFF2E7D32);
    return isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = PrefsRepository.isPremium();
    final color =
        _card != null ? _catColor(_card!.category) : const Color(0xFF1565C0);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Random Practice'),
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // ── Free user: small "Go Premium" chip ─────────────────────────
          if (!isPremium)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/premium'),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFB300).withOpacity(0.5)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.workspace_premium_rounded,
                          size: 13, color: Color(0xFFFFB300)),
                      SizedBox(width: 4),
                      Text('50 cards',
                          style: TextStyle(
                              color: Color(0xFFFFB300),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),

          // ── Session counter ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text('$_sessionCount done',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            )),
          ),
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
              : Column(children: [
                  // ── Free user banner ──────────────────────────────────────
                  if (!isPremium) _buildFreeBanner(isDark),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(children: [
                        _buildPhaseBanner(isDark),
                        const SizedBox(height: 18),
                        _buildTimerRing(isDark),
                        const SizedBox(height: 24),
                        _buildCard(isDark, color),
                        const SizedBox(height: 24),
                        _buildMainActions(isDark, color),
                        const SizedBox(height: 14),
                        _buildSecondaryActions(isDark),
                      ]),
                    ),
                  ),
                  const BannerAdWidget(),
                ]),
    );
  }

  // ── Free tier info banner ──────────────────────────────────────────────────
  Widget _buildFreeBanner(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/premium'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withOpacity(isDark ? 0.12 : 0.10),
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFFFFB300).withOpacity(0.25),
            ),
          ),
        ),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFFFFB300), size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Practising from ${kFreeCardLimit} free cards. '
              'Tap to unlock all 200+.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFFFFB300) : const Color(0xFFE65100),
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 11, color: Color(0xFFFFB300)),
        ]),
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

  Widget _buildPhaseBanner(bool isDark) {
    final configs = {
      _Phase.idle: _BannerConfig(
          icon: Icons.lightbulb_outline_rounded,
          label: 'Read the cue card carefully',
          bg: isDark ? const Color(0xFF1A2E4A) : const Color(0xFFE3F2FD),
          fg: isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0)),
      _Phase.prep: _BannerConfig(
          icon: Icons.psychology_outlined,
          label: 'Preparation time — plan your answer',
          bg: const Color(0xFFFFF8E1),
          fg: const Color(0xFFE65100)),
      _Phase.speaking: _BannerConfig(
          icon: Icons.mic_rounded,
          label: 'Speak now — you are being timed!',
          bg: const Color(0xFFE8F5E9),
          fg: const Color(0xFF2E7D32)),
      _Phase.finished: _BannerConfig(
          icon: Icons.celebration_rounded,
          label: 'Well done! Card saved to practiced ✓',
          bg: const Color(0xFFF3E5F5),
          fg: const Color(0xFF6A1B9A)),
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

  Widget _buildTimerRing(bool isDark) {
    final max = _phase == _Phase.prep
        ? kPrepSeconds.toDouble()
        : kSpeakSeconds.toDouble();
    final progress = (_phase == _Phase.idle || _phase == _Phase.finished)
        ? 1.0
        : _secsLeft / max;
    final tc = _timerColor(isDark);

    return ScaleTransition(
      scale: (_phase == _Phase.speaking && _secsLeft <= 10)
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
            if (_phase == _Phase.idle)
              Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.touch_app_rounded,
                    size: 32,
                    color: isDark
                        ? const Color(0xFF4DB6FF)
                        : const Color(0xFF1565C0)),
                const SizedBox(height: 4),
                Text('Ready?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF4DB6FF)
                            : const Color(0xFF1565C0))),
              ])
            else if (_phase == _Phase.finished)
              const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded,
                    size: 40, color: Color(0xFF2E7D32)),
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
                        fontSize: 34, fontWeight: FontWeight.bold, color: tc)),
                const SizedBox(height: 2),
                Text(_phase == _Phase.prep ? 'PREP' : 'SPEAK',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: tc.withOpacity(0.7))),
              ]),
          ])),
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
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: Color(0xFFFFB300)),
              const SizedBox(width: 6),
              Text('1 min prep  ·  2 min speaking',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFFFB300)
                          : const Color(0xFFE65100))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildMainActions(bool isDark, Color color) {
    switch (_phase) {
      case _Phase.idle:
        return _PrimaryBtn(
            label: 'Start Preparation (1 min)',
            icon: Icons.play_arrow_rounded,
            color: const Color(0xFF1565C0),
            onTap: _startPrep);
      case _Phase.prep:
        return Column(children: [
          _PrimaryBtn(
              label: 'Start Speaking Now',
              icon: Icons.mic_rounded,
              color: const Color(0xFF2E7D32),
              onTap: _startSpeaking),
          const SizedBox(height: 10),
          _SecondaryBtn(
              label: 'Stop',
              icon: Icons.stop_rounded,
              isDark: isDark,
              onTap: _stop),
        ]);
      case _Phase.speaking:
        return _SecondaryBtn(
            label: 'Stop Speaking',
            icon: Icons.stop_rounded,
            isDark: isDark,
            onTap: _stop);
      case _Phase.finished:
        return _PrimaryBtn(
            label: 'Next Card',
            icon: Icons.arrow_forward_rounded,
            color: const Color(0xFF6A1B9A),
            onTap: _nextCard);
    }
  }

  Widget _buildSecondaryActions(bool isDark) {
    return Row(children: [
      Expanded(
          child: _SecondaryBtn(
              label: 'Skip Card',
              icon: Icons.skip_next_rounded,
              isDark: isDark,
              onTap: _nextCard)),
      const SizedBox(width: 12),
      Expanded(
          child: _SecondaryBtn(
              label: 'View Answer',
              icon: Icons.visibility_outlined,
              isDark: isDark,
              onTap: () => Navigator.pushNamed(context, '/cue-card-detail',
                  arguments: {'cardId': _card?.id ?? 1}))),
    ]);
  }
}

// ── Banner config helper ───────────────────────────────────────────────────────
class _BannerConfig {
  final IconData icon;
  final String label;
  final Color bg, fg;
  const _BannerConfig(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.fg});
}

// ── Button widgets ─────────────────────────────────────────────────────────────
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
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 3,
          shadowColor: color.withOpacity(0.4),
        ),
      ));
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
      ));
}
