import 'package:flutter/material.dart';
import '../../data/services/billing_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/premium/premium_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 30, end: 0)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    // Listen to billing state changes
    BillingService.stateNotifier.addListener(_onBillingStateChange);
  }

  @override
  void dispose() {
    BillingService.stateNotifier.removeListener(_onBillingStateChange);
    _animCtrl.dispose();
    super.dispose();
  }

  void _onBillingStateChange() {
    if (!mounted) return;
    final state = BillingService.stateNotifier.value;

    if (state == BillingState.purchased) {
      _showSuccessDialog();
    } else if (state == BillingState.error) {
      _showErrorSnackbar('Purchase failed. Please try again.');
    }
    setState(() {}); // rebuild UI for loading state
  }

  // ── Handle buy button tap ─────────────────────────────────────────────────
  Future<void> _onBuyTapped() async {
    if (BillingService.isPremium) {
      _showSuccessDialog(); // already premium
      return;
    }
    final error = await BillingService.buyPremium();
    if (error != null && mounted) {
      _showErrorSnackbar(error);
    }
    // If error is null → Google Play purchase sheet opened — wait for callback
  }

  // ── Restore purchases (for reinstall) ────────────────────────────────────
  Future<void> _onRestoreTapped() async {
    setState(() {});
    await BillingService.restorePurchases();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(BillingService.isPremium
            ? 'Premium restored successfully! ✓'
            : 'No previous purchase found.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      setState(() {});
    }
  }

  void _showErrorSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFC62828),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.12),
                  shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 40),
            ),
            const SizedBox(height: 18),
            Text('Premium Unlocked! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E))),
            const SizedBox(height: 10),
            Text('All ads have been removed.\nEnjoy ad-free practice forever!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark
                        ? const Color(0xFF8899AA)
                        : const Color(0xFF555577))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Start Practising!',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = BillingService.isPremium;
    final isLoading =
        BillingService.stateNotifier.value == BillingState.loading ||
            BillingService.stateNotifier.value == BillingState.pending;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor:
                isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0D1E30), const Color(0xFF142638)]
                        : [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.workspace_premium_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 12),
                      Text(isPremium ? 'You\'re Premium! ✓' : 'Go Premium',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          isPremium
                              ? 'Enjoy ad-free experience forever'
                              : 'One-time payment • No subscription',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (_, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                    offset: Offset(0, _slideAnim.value), child: child),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  // ── Already premium banner ──────────────────────────────
                  if (isPremium) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFF2E7D32).withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF2E7D32), size: 32),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Premium Active',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF2E7D32))),
                              Text('All ads removed. Enjoy!',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? const Color(0xFF8899AA)
                                          : const Color(0xFF555577))),
                            ])),
                      ]),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Features list ───────────────────────────────────────
                  _buildFeaturesCard(isDark),
                  const SizedBox(height: 20),

                  // ── Price card ──────────────────────────────────────────
                  if (!isPremium) ...[
                    _buildPriceCard(isDark),
                    const SizedBox(height: 20),

                    // ── BUY BUTTON ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _onBuyTapped,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFFFFB300).withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                          shadowColor: const Color(0xFFFFB300).withOpacity(0.4),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.workspace_premium_rounded,
                                      size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Get Lifetime Access — '
                                    '${BillingService.productPrice}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Restore purchases ─────────────────────────────────
                    TextButton(
                      onPressed: isLoading ? null : _onRestoreTapped,
                      child: Text('Restore Previous Purchase',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF4DB6FF)
                                  : const Color(0xFF1565C0))),
                    ),
                    const SizedBox(height: 8),

                    // ── Fine print ────────────────────────────────────────
                    Text(
                      'One-time payment of ${BillingService.productPrice}. '
                      'No subscription. No hidden fees.\n'
                      'Payment processed securely by Google Play.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.6,
                          color: isDark
                              ? const Color(0xFF3A5570)
                              : const Color(0xFFAAAAAA)),
                    ),
                  ],

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Features card ─────────────────────────────────────────────────────────
  Widget _buildFeaturesCard(bool isDark) {
    const features = [
      _Feature(Icons.block_rounded, 'Remove All Ads',
          'No banners, no interstitials — ever'),
      _Feature(Icons.all_inclusive_rounded, 'Unlimited Practice',
          'Practice all 200+ cards without interruption'),
      _Feature(Icons.bolt_rounded, 'Faster Experience',
          'No ad loading delays — instant navigation'),
      _Feature(Icons.update_rounded, 'Free Future Updates',
          'All new cards and features included'),
      _Feature(Icons.devices_rounded, 'One-Time Payment',
          'Pay once, use forever — no subscription'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What you get:',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E))),
        const SizedBox(height: 16),
        ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child:
                        Icon(f.icon, color: const Color(0xFFFFB300), size: 22)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(f.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFE8EAF0)
                                  : const Color(0xFF1A1A2E))),
                      Text(f.subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF557799)
                                  : const Color(0xFF888899))),
                    ])),
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32), size: 20),
              ]),
            )),
      ]),
    );
  }

  // ── Price card ────────────────────────────────────────────────────────────
  Widget _buildPriceCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2E4A), const Color(0xFF0F1B2D)]
              : [const Color(0xFFFFFDE7), const Color(0xFFFFF8E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFFFB300).withOpacity(0.4), width: 1.5),
      ),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Lifetime Access',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100))),
          const SizedBox(height: 4),
          Text('Pay once, use forever',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899))),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.currency_rupee_rounded,
                color: Color(0xFFFFB300), size: 16),
            Text(BillingService.productPrice,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFB300))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('BEST VALUE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32))),
            ),
          ]),
        ])),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.15),
              shape: BoxShape.circle),
          child: const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFFFFB300), size: 32),
        ),
      ]),
    );
  }
}

// ── Feature model ─────────────────────────────────────────────────────────────
class _Feature {
  final IconData icon;
  final String title, subtitle;
  const _Feature(this.icon, this.title, this.subtitle);
}
