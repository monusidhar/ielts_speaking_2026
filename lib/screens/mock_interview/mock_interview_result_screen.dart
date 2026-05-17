import 'package:flutter/material.dart';
import '../../data/models/mock_interview_models.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../data/services/share_service.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/mock_interview/mock_interview_result_screen.dart
//
// Shows comprehensive AI evaluation of the full mock interview.
// Includes per-part scores, criteria breakdown, and premium upsell for free users.
// ─────────────────────────────────────────────────────────────────────────────

class MockInterviewResultScreen extends StatelessWidget {
  final MockInterviewResult result;
  final CueCard card;

  const MockInterviewResultScreen({
    super.key,
    required this.result,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = PrefsRepository.isPremium();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          // Go back to home, clearing the interview stack
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
        body: Column(children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header ─────────────────────────────────────────────────
                SliverToBoxAdapter(child: _buildHeader(isDark)),
                SliverToBoxAdapter(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(children: [
                    // ── Overall band ───────────────────────────────────────
                    _buildOverallBand(isDark),
                    const SizedBox(height: 16),

                    // ── Criteria breakdown ─────────────────────────────────
                    _buildCriteriaCard(isDark),
                    const SizedBox(height: 16),

                    // ── Part scores ────────────────────────────────────────
                    _buildPartScores(isDark),
                    const SizedBox(height: 16),

                    // ── Overall comment ────────────────────────────────────
                    _buildSection(
                      isDark,
                      icon: Icons.chat_rounded,
                      title: 'Overall Assessment',
                      color: const Color(0xFF6A1B9A),
                      child: Text(result.overallComment,
                          style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? const Color(0xFFCDD5E0)
                                  : const Color(0xFF333355),
                              height: 1.6)),
                    ),
                    const SizedBox(height: 16),

                    // ── Strengths ──────────────────────────────────────────
                    _buildSection(
                      isDark,
                      icon: Icons.thumb_up_rounded,
                      title: 'Strengths',
                      color: const Color(0xFF2E7D32),
                      child: Column(
                        children: result.strengths
                            .map((s) => _BulletItem(
                                text: s,
                                color: const Color(0xFF2E7D32),
                                isDark: isDark))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Improvements ───────────────────────────────────────
                    _buildSection(
                      isDark,
                      icon: Icons.trending_up_rounded,
                      title: 'Areas to Improve',
                      color: const Color(0xFFE65100),
                      child: Column(
                        children: result.improvements
                            .map((s) => _BulletItem(
                                text: s,
                                color: const Color(0xFFE65100),
                                isDark: isDark))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Suggested vocabulary ───────────────────────────────
                    if (result.suggestedVocabulary.isNotEmpty)
                      _buildSection(
                        isDark,
                        icon: Icons.spellcheck_rounded,
                        title: 'Suggested Vocabulary',
                        color: const Color(0xFF00695C),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: result.suggestedVocabulary
                              .map((v) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00695C)
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(v,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? const Color(0xFFCDD5E0)
                                                : const Color(0xFF333355))),
                                  ))
                              .toList(),
                        ),
                      ),
                    if (result.suggestedVocabulary.isNotEmpty)
                      const SizedBox(height: 16),

                    // ── Improved Part 2 answer ─────────────────────────────
                    if (result.improvedPart2Answer.isNotEmpty)
                      _buildSection(
                        isDark,
                        icon: Icons.auto_fix_high_rounded,
                        title: 'Improved Part 2 Answer',
                        color: const Color(0xFF1565C0),
                        child: Text(result.improvedPart2Answer,
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFFCDD5E0)
                                    : const Color(0xFF333355),
                                height: 1.6,
                                fontStyle: FontStyle.italic)),
                      ),
                    if (result.improvedPart2Answer.isNotEmpty)
                      const SizedBox(height: 16),

                    // ── Premium upsell for free users ──────────────────────
                    if (!isPremium) ...[
                      _buildPremiumUpsell(context, isDark),
                      const SizedBox(height: 16),
                    ],

                    // ── Done button ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                          Navigator.pushReplacementNamed(
                              context, AppRoutes.home);
                        },
                        icon: const Icon(Icons.home_rounded, size: 20),
                        label: const Text('Back to Home',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A1B9A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                )),
              ],
            ),
          ),
          const BannerAdWidget(),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A0A2E), const Color(0xFF0F1B2D)]
              : [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(children: [
            const Icon(Icons.emoji_events_rounded,
                color: Color(0xFFFFB300), size: 44),
            const SizedBox(height: 12),
            const Text('Mock Interview Complete!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(card.topic,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    height: 1.4)),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => ShareService.shareMockResult(
                overallBand: result.overallBand,
                part1Band: result.part1Band,
                part2Band: result.part2Band,
                part3Band: result.part3Band,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('Share Result',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OVERALL BAND SCORE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverallBand(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      margin: const EdgeInsets.only(top: 20),
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
        Text('OVERALL BAND SCORE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: isDark
                    ? const Color(0xFF8899AA)
                    : const Color(0xFF888899))),
        const SizedBox(height: 12),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                _bandColor(result.overallBand),
                _bandColor(result.overallBand).withOpacity(0.7)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: _bandColor(result.overallBand).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(result.overallBand.toStringAsFixed(1),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),
        Text(_bandLabel(result.overallBand),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _bandColor(result.overallBand))),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRITERIA BREAKDOWN
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCriteriaCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        Text('Criteria Breakdown',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E))),
        const SizedBox(height: 14),
        _CriteriaBar(
            label: 'Fluency & Coherence',
            band: result.fluencyBand,
            isDark: isDark),
        _CriteriaBar(
            label: 'Lexical Resource',
            band: result.lexicalBand,
            isDark: isDark),
        _CriteriaBar(
            label: 'Grammatical Range',
            band: result.grammarBand,
            isDark: isDark),
        _CriteriaBar(
            label: 'Pronunciation',
            band: result.pronunciationBand,
            isDark: isDark),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PART SCORES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPartScores(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        Text('Per-Part Scores',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
              child: _PartScoreTile(
                  part: 'Part 1',
                  subtitle: 'Introduction',
                  band: result.part1Band,
                  color: const Color(0xFF1565C0),
                  isDark: isDark)),
          const SizedBox(width: 10),
          Expanded(
              child: _PartScoreTile(
                  part: 'Part 2',
                  subtitle: 'Cue Card',
                  band: result.part2Band,
                  color: const Color(0xFF2E7D32),
                  isDark: isDark)),
          const SizedBox(width: 10),
          Expanded(
              child: _PartScoreTile(
                  part: 'Part 3',
                  subtitle: 'Discussion',
                  band: result.part3Band,
                  color: const Color(0xFFE65100),
                  isDark: isDark)),
        ]),
        const SizedBox(height: 14),

        // Per-part feedback
        if (result.part1Feedback.isNotEmpty) ...[
          _PartFeedback(
              part: 'Part 1',
              feedback: result.part1Feedback,
              color: const Color(0xFF1565C0),
              isDark: isDark),
          const SizedBox(height: 8),
        ],
        if (result.part2Feedback.isNotEmpty) ...[
          _PartFeedback(
              part: 'Part 2',
              feedback: result.part2Feedback,
              color: const Color(0xFF2E7D32),
              isDark: isDark),
          const SizedBox(height: 8),
        ],
        if (result.part3Feedback.isNotEmpty)
          _PartFeedback(
              part: 'Part 3',
              feedback: result.part3Feedback,
              color: const Color(0xFFE65100),
              isDark: isDark),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GENERIC SECTION CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSection(bool isDark,
      {required IconData icon,
      required String title,
      required Color color,
      required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E))),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PREMIUM UPSELL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPremiumUpsell(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.premium),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB300).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 36),
          const SizedBox(height: 12),
          const Text('Unlock Unlimited Mock Interviews',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Your free trial is over. Upgrade to Premium for\nunlimited daily mock interviews + all cue cards!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Upgrade Now — ₹199 Lifetime',
                style: TextStyle(
                    color: Color(0xFFFF8F00),
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Color _bandColor(double band) {
    if (band >= 7.0) return const Color(0xFF2E7D32);
    if (band >= 6.0) return const Color(0xFF1565C0);
    if (band >= 5.0) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  String _bandLabel(double band) {
    if (band >= 8.0) return 'Expert User';
    if (band >= 7.0) return 'Good User';
    if (band >= 6.0) return 'Competent User';
    if (band >= 5.0) return 'Modest User';
    if (band >= 4.0) return 'Limited User';
    return 'Needs Improvement';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CriteriaBar extends StatelessWidget {
  final String label;
  final double band;
  final bool isDark;
  const _CriteriaBar(
      {required this.label, required this.band, required this.isDark});

  Color get _color {
    if (band >= 7.0) return const Color(0xFF2E7D32);
    if (band >= 6.0) return const Color(0xFF1565C0);
    if (band >= 5.0) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355))),
            Text(band.toStringAsFixed(1),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: _color)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (band / 9.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor:
                  isDark ? const Color(0xFF0F1B2D) : const Color(0xFFEEEEF5),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
        ]),
      );
}

class _PartScoreTile extends StatelessWidget {
  final String part, subtitle;
  final double band;
  final Color color;
  final bool isDark;
  const _PartScoreTile(
      {required this.part,
      required this.subtitle,
      required this.band,
      required this.color,
      required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(band.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(part,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E))),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFF8899AA)
                      : const Color(0xFF888899))),
        ]),
      );
}

class _PartFeedback extends StatelessWidget {
  final String part, feedback;
  final Color color;
  final bool isDark;
  const _PartFeedback(
      {required this.part,
      required this.feedback,
      required this.color,
      required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(part,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(feedback,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355),
                    height: 1.5)),
          ),
        ]),
      );
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;
  const _BulletItem(
      {required this.text, required this.color, required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355),
                    height: 1.5)),
          ),
        ]),
      );
}
