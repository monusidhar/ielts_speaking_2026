import 'package:flutter/material.dart';
import '../../data/app_secrets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/privacy/privacy_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//
// IMPORTS in main.dart — uncomment:
//   import 'screens/privacy/privacy_screen.dart';
//
// Replace placeholder in routes:
//   AppRoutes.privacy: (ctx) => const PrivacyScreen(),
// ─────────────────────────────────────────────────────────────────────────────

// ── Privacy section model ─────────────────────────────────────────────────────
class _PrivacySection {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _PrivacySection({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

// ── Privacy policy content ─────────────────────────────────────────────────────
const String _lastUpdated = 'January 2026';
const String _appName = 'IELTS Speaking 2026';
const String _contactEmail = AppSecrets.contactEmail; // from app_secrets.dart

final List<_PrivacySection> _sections = [
  _PrivacySection(
    icon: Icons.info_outline_rounded,
    color: const Color(0xFF1565C0),
    title: 'About This App',
    body: '$_appName is an offline IELTS Speaking preparation application. '
        'It provides cue cards, Band 7–8 sample answers, vocabulary lists, '
        'and timed practice modes to help users prepare for the IELTS Speaking test.\n\n'
        'This app is not affiliated with, endorsed by, or connected to IELTS, '
        'the British Council, IDP Education, or Cambridge Assessment English.',
  ),
  _PrivacySection(
    icon: Icons.storage_rounded,
    color: const Color(0xFF2E7D32),
    title: 'Data We Collect',
    body: 'This app does NOT collect any personal information. '
        'We do not collect your name, email address, phone number, or any '
        'personally identifiable information.\n\n'
        'All data (bookmarks, practice history, settings, and preferences) '
        'is stored locally on your device only and is never transmitted '
        'to any server or third party.',
  ),
  _PrivacySection(
    icon: Icons.phone_android_rounded,
    color: const Color(0xFF6A1B9A),
    title: 'Local Storage',
    body: 'The app uses SharedPreferences to store:\n'
        '• Your bookmarked cue cards\n'
        '• Your dark mode preference\n'
        '• Your practice history and count\n'
        '• Your premium purchase status\n\n'
        'This data is stored entirely on your device and can be cleared '
        'at any time by uninstalling the app.',
  ),
  _PrivacySection(
    icon: Icons.ads_click_rounded,
    color: const Color(0xFFE65100),
    title: 'Advertisements',
    body: 'The free version of this app displays advertisements provided by '
        'Google AdMob. AdMob may collect certain data as described in '
        'Google\'s Privacy Policy, including device identifiers and '
        'usage data for ad personalisation purposes.\n\n'
        'You can remove all ads permanently by upgrading to the Premium '
        'version. Premium users are never shown advertisements.',
  ),
  _PrivacySection(
    icon: Icons.payment_rounded,
    color: const Color(0xFF00695C),
    title: 'In-App Purchases',
    body: 'This app offers a one-time lifetime premium purchase of ₹199 '
        'via Google Play Billing. All payment processing is handled '
        'entirely by Google Play. We do not store or process any '
        'payment card information directly.\n\n'
        'Your purchase is tied to your Google Play account and can be '
        'restored on any device using the same account.',
  ),
  _PrivacySection(
    icon: Icons.wifi_off_rounded,
    color: const Color(0xFF1565C0),
    title: 'Internet Access',
    body: 'The core features of this app work fully offline. '
        'Internet access is only used for:\n'
        '• Loading advertisements (free version only)\n'
        '• Verifying in-app purchases via Google Play\n\n'
        'No user data is sent to our servers at any time.',
  ),
  _PrivacySection(
    icon: Icons.child_care_rounded,
    color: const Color(0xFFEF6C00),
    title: 'Children\'s Privacy',
    body: 'This app is not directed at children under the age of 13. '
        'We do not knowingly collect any personal information from children. '
        'If you believe a child has provided personal information, '
        'please contact us and we will promptly delete it.',
  ),
  _PrivacySection(
    icon: Icons.update_rounded,
    color: const Color(0xFF37474F),
    title: 'Changes to This Policy',
    body: 'We may update this Privacy Policy from time to time. '
        'Any changes will be reflected in the "Last Updated" date above. '
        'Continued use of the app after changes constitutes acceptance '
        'of the updated policy.\n\n'
        'We encourage you to review this policy periodically.',
  ),
  _PrivacySection(
    icon: Icons.mail_outline_rounded,
    color: const Color(0xFF558B2F),
    title: 'Contact Us',
    body: 'If you have any questions, concerns, or requests regarding '
        'this Privacy Policy or our data practices, please contact us at:\n\n'
        '$_contactEmail\n\n'
        'We will respond to all enquiries within 7 business days.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  // Track which sections are expanded
  final Set<int> _expanded = {};

  void _toggle(int index) {
    setState(() {
      if (_expanded.contains(index)) {
        _expanded.remove(index);
      } else {
        _expanded.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Expand all / Collapse all toggle
          TextButton(
            onPressed: () {
              setState(() {
                if (_expanded.length == _sections.length) {
                  _expanded.clear();
                } else {
                  _expanded.addAll(List.generate(_sections.length, (i) => i));
                }
              });
            },
            child: Text(
              _expanded.length == _sections.length ? 'Collapse' : 'Expand All',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Header card ─────────────────────────────────────────────
          _buildHeaderCard(isDark),
          const SizedBox(height: 16),

          // ── Disclaimer banner ───────────────────────────────────────
          _buildDisclaimerBanner(isDark),
          const SizedBox(height: 20),

          // ── Section label ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Policy Details',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E),
              ),
            ),
          ),

          // ── Expandable sections ─────────────────────────────────────
          ...List.generate(_sections.length, (i) {
            return _PrivacySectionCard(
              section: _sections[i],
              isDark: isDark,
              isExpanded: _expanded.contains(i),
              onTap: () => _toggle(i),
            );
          }),

          const SizedBox(height: 8),

          // ── Footer ──────────────────────────────────────────────────
          _buildFooter(isDark),
        ],
      ),
    );
  }

  // ── Header card ────────────────────────────────────────────────────────────
  Widget _buildHeaderCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D1E30), const Color(0xFF142638)]
              : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.privacy_tip_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last updated: $_lastUpdated',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _appName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.55),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer banner ──────────────────────────────────────────────────────
  Widget _buildDisclaimerBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE65100).withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This app is not affiliated with IELTS, the British Council, '
              'IDP Education, or Cambridge Assessment English. '
              'All content is original and independently created.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFFFFAA77) : const Color(0xFFBF360C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.verified_user_rounded,
              size: 32,
              color:
                  isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0)),
          const SizedBox(height: 10),
          Text(
            'Your privacy matters to us',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This app is 100% offline. No personal data is ever '
            'collected, stored on servers, or shared with third parties.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: isDark ? const Color(0xFF557799) : const Color(0xFF888899),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '© 2026 $_appName · $_contactEmail',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF3A5570) : const Color(0xFFBBBBCC),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPANDABLE SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PrivacySectionCard extends StatelessWidget {
  final _PrivacySection section;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onTap;

  const _PrivacySectionCard({
    required this.section,
    required this.isDark,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded
                  ? section.color.withOpacity(0.35)
                  : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: isExpanded
                          ? section.color.withOpacity(0.08)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: isExpanded ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              // ── Header row ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: section.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(section.icon, color: section.color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    // Title
                    Expanded(
                      child: Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFE8EAF0)
                              : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    // Animated chevron
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 260),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: isDark
                            ? const Color(0xFF3A5570)
                            : const Color(0xFFCCCCDD),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Expanded body ──────────────────────────────────────
              if (isExpanded) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: isDark
                      ? const Color(0xFF253A4A)
                      : const Color(0xFFEEEEF5),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Text(
                    section.body,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.7,
                      color: isDark
                          ? const Color(0xFFCDD5E0)
                          : const Color(0xFF333355),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
