import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../data/services/ai_service.dart';
import '../../data/app_secrets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/about/about_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//
// IMPORTS in main.dart — uncomment:
//   import 'screens/about/about_screen.dart';
//
// Replace placeholder in routes:
//   AppRoutes.about: (ctx) => const AboutScreen(),
//
// DEPENDENCIES — add to pubspec.yaml:
//   package_info_plus: ^8.0.0   ← for real version number
//   url_launcher: ^6.3.0        ← for opening links
// ─────────────────────────────────────────────────────────────────────────────

// ── App constants ──────────────────────────────────────────────────────────────
const String _developerName = 'Monu Sidhar';
const String _contactEmail = AppSecrets.contactEmail;
const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.monusidhar.ielts_speaking_2026';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late List<Animation<double>> _anims;

  // Easter egg: tap logo 5 times
  int _logoTaps = 0;
  int _versionTaps = 0;

  // Dynamic version from package_info_plus
  String _appVersion = '...';
  String _appBuild = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anims = List.generate(6, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(
            i * 0.1,
            (i * 0.1) + 0.5,
            curve: Curves.easeOut,
          ),
        ),
      );
    });
    _animCtrl.forward();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
        _appBuild = info.buildNumber;
      });
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    _logoTaps++;
    if (_logoTaps >= 5) {
      _logoTaps = 0;
      HapticFeedback.heavyImpact();
      _showEasterEgg();
    }
  }

  void _showEasterEgg() {
    showDialog(
      context: context,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text(
                  'You found the Easter Egg!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep practising and you\'ll get that Band 9! 🚀',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF8899AA)
                        : const Color(0xFF555577),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Thanks! 😄',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copyEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _contactEmail));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Email copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onVersionTap() {
    _versionTaps++;
    if (_versionTaps >= 7) {
      _versionTaps = 0;
      HapticFeedback.heavyImpact();
      _showDevStats();
    } else if (_versionTaps >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${7 - _versionTaps} taps to developer stats'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showDevStats() async {
    final stats = await AiService.getApiStats();
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.developer_mode_rounded,
                size: 40,
                color:
                    isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0)),
            const SizedBox(height: 12),
            Text('AI API Stats',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E))),
            const SizedBox(height: 16),
            _StatRow(
                label: 'Total API Calls',
                value: '${stats['total_calls']}',
                isDark: isDark),
            _StatRow(
                label: 'Failed Calls',
                value: '${stats['total_fails']}',
                isDark: isDark),
            _StatRow(
                label: 'Rate Limit Hits (429)',
                value: '${stats['rate_limits']}',
                isDark: isDark,
                isWarning: (stats['rate_limits'] as int) > 0),
            _StatRow(
                label: 'Last Error',
                value: '${stats['last_error']}',
                isDark: isDark),
            const SizedBox(height: 8),
            Divider(
                color:
                    isDark ? const Color(0xFF2A3E55) : const Color(0xFFDDDDEE)),
            const SizedBox(height: 8),
            Text('Groq Free: 14,400 req/day, 30 req/min',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF557799)
                        : const Color(0xFF888899))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          children: [
            // ── App identity ────────────────────────────────────────────
            _FadeSlide(
              anim: _anims[0],
              child: _buildAppIdentity(isDark),
            ),
            const SizedBox(height: 24),

            // ── Stats banner ────────────────────────────────────────────
            _FadeSlide(
              anim: _anims[1],
              child: _buildStatsBanner(isDark),
            ),
            const SizedBox(height: 24),

            // ── App info rows ───────────────────────────────────────────
            _FadeSlide(
              anim: _anims[2],
              child: _buildInfoCard(isDark),
            ),
            const SizedBox(height: 16),

            // ── Quick links ─────────────────────────────────────────────
            _FadeSlide(
              anim: _anims[3],
              child: _buildQuickLinks(isDark),
            ),
            const SizedBox(height: 16),

            // ── Rate & share ────────────────────────────────────────────
            _FadeSlide(
              anim: _anims[4],
              child: _buildRateShare(isDark),
            ),
            const SizedBox(height: 24),

            // ── Disclaimer + copyright ──────────────────────────────────
            _FadeSlide(
              anim: _anims[5],
              child: _buildFooter(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── App identity: logo + name + version ────────────────────────────────────
  Widget _buildAppIdentity(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D1E30), const Color(0xFF142638)]
              : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tappable logo (easter egg)
          GestureDetector(
            onTap: _onLogoTap,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
                border:
                    Border.all(color: Colors.white.withOpacity(0.25), width: 2),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'IE',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'SPEAKING',
                    style: TextStyle(
                      fontSize: 7,
                      color: Colors.white,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'IELTS Speaking 2026',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 6),

          GestureDetector(
            onTap: _onVersionTap,
            child: Text(
              'Version $_appVersion (Build $_appBuild)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
                letterSpacing: 0.3,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Made with ❤️ for IELTS Aspirants',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats banner: 3 numbers ────────────────────────────────────────────────
  Widget _buildStatsBanner(bool isDark) {
    return Row(
      children: [
        _StatBubble(
            value: '200+',
            label: 'Cue Cards',
            color: const Color(0xFF1565C0),
            isDark: isDark),
        const SizedBox(width: 10),
        _StatBubble(
            value: '500+',
            label: 'Vocab Words',
            color: const Color(0xFF2E7D32),
            isDark: isDark),
        const SizedBox(width: 10),
        _StatBubble(
            value: '100%',
            label: 'Offline',
            color: const Color(0xFF6A1B9A),
            isDark: isDark),
      ],
    );
  }

  // ── Info rows card ─────────────────────────────────────────────────────────
  Widget _buildInfoCard(bool isDark) {
    final rows = [
      _InfoRow(
        icon: Icons.person_outline_rounded,
        label: 'Developer',
        value: _developerName,
        color: const Color(0xFF1565C0),
      ),
      _InfoRow(
        icon: Icons.code_rounded,
        label: 'Built With',
        value: 'Flutter · Dart · Material 3',
        color: const Color(0xFF00695C),
      ),
      _InfoRow(
        icon: Icons.category_outlined,
        label: 'Category',
        value: 'Education · IELTS Preparation',
        color: const Color(0xFF6A1B9A),
      ),
      _InfoRow(
        icon: Icons.language_rounded,
        label: 'Language',
        value: 'English',
        color: const Color(0xFF558B2F),
      ),
      _InfoRow(
        icon: Icons.android_rounded,
        label: 'Platform',
        value: 'Android (Flutter)',
        color: const Color(0xFF2E7D32),
      ),
      _InfoRow(
        icon: Icons.update_rounded,
        label: 'Last Updated',
        value: 'January 2026',
        color: const Color(0xFF37474F),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          return Column(
            children: [
              _InfoTile(row: rows[i], isDark: isDark),
              if (i < rows.length - 1)
                Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                  color: isDark
                      ? const Color(0xFF253A4A)
                      : const Color(0xFFEEEEF5),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ── Quick links ────────────────────────────────────────────────────────────
  Widget _buildQuickLinks(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          _LinkTile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            color: const Color(0xFF1565C0),
            isDark: isDark,
            onTap: () => Navigator.pushNamed(context, '/privacy'),
          ),
          Divider(
            height: 1,
            indent: 60,
            endIndent: 16,
            color: isDark ? const Color(0xFF253A4A) : const Color(0xFFEEEEF5),
          ),
          _LinkTile(
            icon: Icons.mail_outline_rounded,
            label: 'Contact Support',
            sublabel: _contactEmail,
            color: const Color(0xFF2E7D32),
            isDark: isDark,
            onTap: () => _copyEmail(context),
            trailing: Icons.copy_rounded,
          ),
          Divider(
            height: 1,
            indent: 60,
            endIndent: 16,
            color: isDark ? const Color(0xFF253A4A) : const Color(0xFFEEEEF5),
          ),
          _LinkTile(
            icon: Icons.workspace_premium_rounded,
            label: 'Go Premium — ₹199',
            sublabel: 'Remove ads · Lifetime access',
            color: const Color(0xFF6A1B9A),
            isDark: isDark,
            onTap: () => Navigator.pushNamed(context, '/premium'),
          ),
        ],
      ),
    );
  }

  // ── Rate & share ───────────────────────────────────────────────────────────
  Widget _buildRateShare(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.star_rounded,
            label: 'Rate Us',
            sublabel: 'on Play Store',
            color: const Color(0xFFFFB300),
            isDark: isDark,
            onTap: () async {
              final uri = Uri.parse(_playStoreUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.share_rounded,
            label: 'Share App',
            sublabel: 'with friends',
            color: const Color(0xFF0288D1),
            isDark: isDark,
            onTap: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'Practice IELTS Speaking with AI feedback! Get band scores, 200+ cue cards & tips.\n\nDownload free: $_playStoreUrl',
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        // Disclaimer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE65100).withOpacity(isDark ? 0.10 : 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE65100).withOpacity(0.25),
            ),
          ),
          child: Text(
            'This app is not affiliated with IELTS, the British Council, '
            'IDP Education, or Cambridge Assessment English. '
            'All content is original and created independently for '
            'educational purposes only.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: isDark ? const Color(0xFFFFAA77) : const Color(0xFFBF360C),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Copyright
        Text(
          '© 2026 IELTS Speaking 2026\nAll rights reserved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.6,
            color: isDark ? const Color(0xFF3A5570) : const Color(0xFFBBBBCC),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

// Fade + slide-up animation wrapper
class _FadeSlide extends StatelessWidget {
  final Animation<double> anim;
  final Widget child;
  const _FadeSlide({required this.anim, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - anim.value)),
          child: child,
        ),
      ),
    );
  }
}

// Stats bubble
class _StatBubble extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isDark;
  const _StatBubble({
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color:
                    isDark ? const Color(0xFF557799) : const Color(0xFF888899),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Info row model
class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

// Info tile widget
class _InfoTile extends StatelessWidget {
  final _InfoRow row;
  final bool isDark;
  const _InfoTile({required this.row, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: row.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(row.icon, color: row.color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF557799)
                        : const Color(0xFF888899),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Link tile widget
class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final IconData? trailing;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.sublabel,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFE8EAF0)
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? const Color(0xFF557799)
                            : const Color(0xFF888899),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              trailing ?? Icons.arrow_forward_ios_rounded,
              size: trailing != null ? 16 : 14,
              color: isDark ? const Color(0xFF3A5570) : const Color(0xFFCCCCDD),
            ),
          ],
        ),
      ),
    );
  }
}

// Action card (Rate / Share)
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color:
                    isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 11,
                color:
                    isDark ? const Color(0xFF557799) : const Color(0xFF888899),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Developer stats row
class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool isWarning;
  const _StatRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF8899AA)
                        : const Color(0xFF555577)))),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isWarning
                    ? const Color(0xFFC62828)
                    : (isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E)))),
      ]),
    );
  }
}
