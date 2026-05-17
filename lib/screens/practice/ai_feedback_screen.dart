import 'package:flutter/material.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/share_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/practice/ai_feedback_screen.dart
//
// Full AI feedback breakdown: band scores, strengths, improvements,
// suggested vocabulary, and improved answer. Shown after AI analysis.
// ─────────────────────────────────────────────────────────────────────────────

class AiFeedbackScreen extends StatefulWidget {
  final AiFeedback feedback;
  final CueCard card;
  final String transcript;

  const AiFeedbackScreen({
    super.key,
    required this.feedback,
    required this.card,
    required this.transcript,
  });

  @override
  State<AiFeedbackScreen> createState() => _AiFeedbackScreenState();
}

class _AiFeedbackScreenState extends State<AiFeedbackScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late List<Animation<double>> _fadeAnims;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnims = List.generate(
        7,
        (i) => Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
            parent: _animCtrl,
            curve:
                Interval(i * 0.08, (i * 0.08) + 0.4, curve: Curves.easeOut))));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final f = widget.feedback;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero header with band score ────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor:
                isDark ? const Color(0xFF0F1B2D) : _bandColor(f.overallBand),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share Score',
                onPressed: () => ShareService.shareBandScore(
                  overallBand: f.overallBand,
                  topic: widget.card.topic,
                  fluency: f.fluencyBand,
                  lexical: f.lexicalBand,
                  grammar: f.grammarBand,
                  pronunciation: f.pronunciationBand,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _bandColor(f.overallBand),
                      _bandColor(f.overallBand).withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      const Text('Your IELTS Band Score',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(f.overallBand.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      Text(_bandLabel(f.overallBand),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(widget.card.topic,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Band Breakdown ───────────────────────────────────────────
                _FadeIn(
                    anim: _fadeAnims[0], child: _buildBandBreakdown(isDark, f)),
                const SizedBox(height: 16),

                // ── Overall Comment ──────────────────────────────────────────
                _FadeIn(
                    anim: _fadeAnims[1],
                    child: _buildSection(isDark, Icons.comment_rounded,
                        'AI Assessment', const Color(0xFF1565C0),
                        child: Text(f.overallComment,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: isDark
                                    ? const Color(0xFFCDD5E0)
                                    : const Color(0xFF333355))))),
                const SizedBox(height: 16),

                // ── Strengths ────────────────────────────────────────────────
                _FadeIn(
                    anim: _fadeAnims[2],
                    child: _buildSection(isDark, Icons.thumb_up_rounded,
                        'Strengths', const Color(0xFF2E7D32),
                        child: _buildBullets(
                            f.strengths, const Color(0xFF2E7D32), isDark))),
                const SizedBox(height: 16),

                // ── Areas to Improve ─────────────────────────────────────────
                _FadeIn(
                    anim: _fadeAnims[3],
                    child: _buildSection(isDark, Icons.trending_up_rounded,
                        'Areas to Improve', const Color(0xFFE65100),
                        child: _buildBullets(
                            f.improvements, const Color(0xFFE65100), isDark))),
                const SizedBox(height: 16),

                // ── Suggested Vocabulary ─────────────────────────────────────
                _FadeIn(
                    anim: _fadeAnims[4],
                    child: _buildSection(isDark, Icons.spellcheck_rounded,
                        'Suggested Vocabulary', const Color(0xFF00695C),
                        child:
                            _buildVocabChips(f.suggestedVocabulary, isDark))),
                const SizedBox(height: 16),

                // ── Improved Answer ──────────────────────────────────────────
                _FadeIn(
                    anim: _fadeAnims[5],
                    child: _buildSection(isDark, Icons.auto_fix_high_rounded,
                        'Improved Version', const Color(0xFF6A1B9A),
                        child: Text(f.improvedAnswer,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.65,
                                fontStyle: FontStyle.italic,
                                color: isDark
                                    ? const Color(0xFFCDD5E0)
                                    : const Color(0xFF333355))))),
                const SizedBox(height: 16),

                // ── Your Transcript (with pronunciation highlights) ────────
                _FadeIn(
                    anim: _fadeAnims[6],
                    child: _buildSection(
                        isDark,
                        Icons.record_voice_over_rounded,
                        'Your Response',
                        isDark
                            ? const Color(0xFF4DB6FF)
                            : const Color(0xFF1565C0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHighlightedTranscript(isDark, f),
                            if (f.pronunciationFlags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE65100)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                        color: const Color(0xFFE65100)
                                            .withOpacity(0.5)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Highlighted words may need pronunciation practice',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: isDark
                                        ? const Color(0xFF557799)
                                        : const Color(0xFF999999),
                                  ),
                                ),
                              ]),
                            ],
                          ],
                        ))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedTranscript(bool isDark, AiFeedback f) {
    final transcript = widget.transcript;
    if (f.pronunciationFlags.isEmpty) {
      return Text(transcript,
          style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color:
                  isDark ? const Color(0xFF8899AA) : const Color(0xFF555577)));
    }

    // Build a set of lowercase flagged words for matching
    final flaggedWords =
        f.pronunciationFlags.map((w) => w.toLowerCase()).toSet();

    // Split transcript into words while preserving whitespace/punctuation
    final pattern = RegExp(r"(\b\w+\b)");
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in pattern.allMatches(transcript)) {
      // Add text before this word (spaces, punctuation)
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: transcript.substring(lastEnd, match.start)));
      }

      final word = match.group(0)!;
      final isHighlighted = flaggedWords.contains(word.toLowerCase());

      if (isHighlighted) {
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

    // Add any trailing text
    if (lastEnd < transcript.length) {
      spans.add(TextSpan(text: transcript.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13.5,
          height: 1.6,
          color: isDark ? const Color(0xFF8899AA) : const Color(0xFF555577),
        ),
        children: spans,
      ),
    );
  }

  Widget _buildBandBreakdown(bool isDark, AiFeedback f) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Band Breakdown',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E))),
        const SizedBox(height: 16),
        _BandBar(
            label: 'Fluency & Coherence', band: f.fluencyBand, isDark: isDark),
        const SizedBox(height: 12),
        _BandBar(
            label: 'Lexical Resource', band: f.lexicalBand, isDark: isDark),
        const SizedBox(height: 12),
        _BandBar(
            label: 'Grammatical Range', band: f.grammarBand, isDark: isDark),
        const SizedBox(height: 12),
        _BandBar(
            label: 'Pronunciation*', band: f.pronunciationBand, isDark: isDark),
        const SizedBox(height: 10),
        Text(
            '* Pronunciation is estimated from text patterns — actual score may vary.',
            style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: isDark
                    ? const Color(0xFF446688)
                    : const Color(0xFF999999))),
      ]),
    );
  }

  Widget _buildSection(bool isDark, IconData icon, String title, Color color,
      {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 17)),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _buildBullets(List<String> items, Color color, bool isDark) {
    return Column(
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(item,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.5,
                                    color: isDark
                                        ? const Color(0xFFCDD5E0)
                                        : const Color(0xFF333355)))),
                      ]),
                ))
            .toList());
  }

  Widget _buildVocabChips(List<String> items, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00695C).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF00695C).withOpacity(0.2)),
                ),
                child: Text(item,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF00695C),
                        fontWeight: FontWeight.w500)),
              ))
          .toList(),
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

// ── Band progress bar ────────────────────────────────────────────────────────
class _BandBar extends StatelessWidget {
  final String label;
  final double band;
  final bool isDark;
  const _BandBar(
      {required this.label, required this.band, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = _AiFeedbackScreenState._bandColor(band);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: isDark
                        ? const Color(0xFF8899AA)
                        : const Color(0xFF555577)))),
        Text(band.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: band / 9.0,
          minHeight: 6,
          backgroundColor:
              isDark ? const Color(0xFF0F1B2D) : const Color(0xFFEEEEF5),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }
}

// ── Fade-in animation wrapper ────────────────────────────────────────────────
class _FadeIn extends StatelessWidget {
  final Animation<double> anim;
  final Widget child;
  const _FadeIn({required this.anim, required this.child});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - anim.value)),
            child: child,
          ),
        ),
      );
}
