import 'package:flutter/material.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../widgets/banner_ad_widget.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/mock_interview/mock_interview_intro_screen.dart
//
// Entry point for the Full Mock Interview. Explains format, checks credits,
// and navigates to the actual interview screen.
// ─────────────────────────────────────────────────────────────────────────────

class MockInterviewIntroScreen extends StatelessWidget {
  const MockInterviewIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canStart = PrefsRepository.canDoMockInterview();
    final isPremium = PrefsRepository.isPremium();
    final remaining = PrefsRepository.getMockRemaining();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Mock Interview'),
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(children: [
              // ── Header icon ──────────────────────────────────────────────
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6A1B9A).withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Full IELTS Speaking\nMock Test',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Experience a complete IELTS Speaking test\nwith AI-powered evaluation',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF8899AA)
                      : const Color(0xFF555577),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Test format card ─────────────────────────────────────────
              _buildFormatCard(isDark),
              const SizedBox(height: 16),

              // ── Credit status ────────────────────────────────────────────
              _buildCreditCard(isDark, isPremium, remaining),
              const SizedBox(height: 16),

              // ── Important notes ──────────────────────────────────────────
              _buildNotesCard(isDark),
              const SizedBox(height: 28),

              // ── Start button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: canStart
                      ? () =>
                          Navigator.pushNamed(context, AppRoutes.mockInterview)
                      : () => Navigator.pushNamed(context, AppRoutes.premium),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canStart
                        ? const Color(0xFF6A1B9A)
                        : const Color(0xFFFFB300),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: canStart ? 4 : 2,
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            canStart
                                ? Icons.play_arrow_rounded
                                : Icons.workspace_premium_rounded,
                            size: 22),
                        const SizedBox(width: 8),
                        Text(
                          canStart
                              ? 'Start Mock Interview'
                              : 'Upgrade to Premium',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ]),
                ),
              ),

              if (!canStart && !isPremium) ...[
                const SizedBox(height: 12),
                Text(
                  'You\'ve used your free trial. Upgrade for unlimited mock interviews!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFE65100),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ]),
          ),
        ),
        const BannerAdWidget(),
      ]),
    );
  }

  Widget _buildFormatCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          const Icon(Icons.format_list_numbered_rounded,
              color: Color(0xFF6A1B9A), size: 20),
          const SizedBox(width: 8),
          Text('Test Format',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E))),
        ]),
        const SizedBox(height: 16),
        _FormatStep(
          number: '1',
          title: 'Part 1 — Introduction',
          subtitle: '6 questions • ~3 minutes',
          description: 'Short answers on everyday topics',
          color: const Color(0xFF1565C0),
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _FormatStep(
          number: '2',
          title: 'Part 2 — Cue Card',
          subtitle: '1 min prep + 2 min speaking',
          description: 'Long turn on a given topic',
          color: const Color(0xFF2E7D32),
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _FormatStep(
          number: '3',
          title: 'Part 3 — Discussion',
          subtitle: '4 questions • ~3 minutes',
          description: 'In-depth questions on Part 2 theme',
          color: const Color(0xFFE65100),
          isDark: isDark,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6A1B9A).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.timer_outlined,
                color: Color(0xFF6A1B9A), size: 16),
            const SizedBox(width: 8),
            Text('Total duration: ~10-12 minutes',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF6A1B9A))),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCreditCard(bool isDark, bool isPremium, int remaining) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFFFFB300), const Color(0xFFFF8F00)]
              : [
                  isDark ? const Color(0xFF1A2E4A) : const Color(0xFFE3F2FD),
                  isDark ? const Color(0xFF1A2E4A) : const Color(0xFFBBDEFB),
                ],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(
          isPremium ? Icons.auto_awesome_rounded : Icons.stars_rounded,
          color: isPremium
              ? Colors.white
              : (isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0)),
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isPremium ? 'Premium Member' : 'Free Plan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isPremium
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E)),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isPremium
                  ? '$remaining of ${PrefsRepository.mockDailyLimitPremium} remaining today'
                  : remaining > 0
                      ? '1 free trial available'
                      : 'Free trial used',
              style: TextStyle(
                fontSize: 12,
                color: isPremium
                    ? Colors.white.withOpacity(0.85)
                    : (isDark
                        ? const Color(0xFF8899AA)
                        : const Color(0xFF555577)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildNotesCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A2E4A).withOpacity(0.5)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded,
              color: isDark ? const Color(0xFFFFB300) : const Color(0xFFE65100),
              size: 18),
          const SizedBox(width: 8),
          Text('Before You Start',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFFFB300)
                      : const Color(0xFFE65100))),
        ]),
        const SizedBox(height: 10),
        _NoteItem(text: 'Find a quiet place to speak', isDark: isDark),
        _NoteItem(
            text: 'Allow microphone access when prompted', isDark: isDark),
        _NoteItem(text: 'Speak clearly in English', isDark: isDark),
        _NoteItem(text: 'Don\'t close the app during the test', isDark: isDark),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FormatStep extends StatelessWidget {
  final String number, title, subtitle, description;
  final Color color;
  final bool isDark;
  const _FormatStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.isDark,
  });
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(number,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFE8EAF0)
                          : const Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500, color: color)),
              const SizedBox(height: 2),
              Text(description,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF8899AA)
                          : const Color(0xFF888899))),
            ]),
          ),
        ],
      );
}

class _NoteItem extends StatelessWidget {
  final String text;
  final bool isDark;
  const _NoteItem({required this.text, required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline_rounded,
                size: 14,
                color:
                    isDark ? const Color(0xFF8899AA) : const Color(0xFF888899)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355),
                    height: 1.4)),
          ),
        ]),
      );
}
