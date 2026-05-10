import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../widgets/banner_ad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/cue_cards/cue_card_detail_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Color> _catColors = {
  'Travel':     Color(0xFF0288D1),
  'Education':  Color(0xFF2E7D32),
  'Personal':   Color(0xFF6A1B9A),
  'People':     Color(0xFFE65100),
  'Arts':       Color(0xFFC62828),
  'Society':    Color(0xFF37474F),
  'Culture':    Color(0xFF00695C),
  'Technology': Color(0xFF1565C0),
  'Sports':     Color(0xFF558B2F),
  'Work':       Color(0xFF4E342E),
  'Food':       Color(0xFFEF6C00),
  'Nature':     Color(0xFF1B5E20),
};
Color _catColor(String cat) => _catColors[cat] ?? const Color(0xFF1565C0);

const Map<String, Color> _posColors = {
  'adjective': Color(0xFF1565C0),
  'noun':      Color(0xFF6A1B9A),
  'verb':      Color(0xFF2E7D32),
  'adverb':    Color(0xFF00695C),
  'phrase':    Color(0xFFE65100),
};

class CueCardDetailScreen extends StatefulWidget {
  final int cardId;
  const CueCardDetailScreen({super.key, required this.cardId});

  @override
  State<CueCardDetailScreen> createState() => _CueCardDetailScreenState();
}

class _CueCardDetailScreenState extends State<CueCardDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  CueCard? _card;
  bool     _isLoading    = true;
  bool     _isBookmarked = false;
  bool     _isLocked     = false;   // true when card is premium and user is free
  bool     _showAnswer   = false;
  String?  _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadCard();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCard() async {
    try {
      final card = await CueCardRepository.getById(widget.cardId);
      if (mounted) {
        setState(() {
          _card          = card;
          _isLoading     = false;
          _error         = card == null ? 'Card not found.' : null;
          _isBookmarked  = PrefsRepository.isBookmarked(widget.cardId);
          // Lock if card ID exceeds free limit and user is not premium
          _isLocked      = card != null &&
              !PrefsRepository.isPremium() &&
              card.id > kFreeCardLimit;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to load card.'; _isLoading = false; });
    }
  }

  // ── Toggle bookmark — persists to SharedPreferences ───────────────────────
  Future<void> _toggleBookmark() async {
    HapticFeedback.lightImpact();
    final nowBookmarked = await PrefsRepository.toggleBookmark(widget.cardId);
    if (mounted) setState(() => _isBookmarked = nowBookmarked);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nowBookmarked ? 'Added to bookmarks ✓' : 'Removed from bookmarks'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Loading ───────────────────────────────────────────────────────────────
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
        body: Center(child: CircularProgressIndicator(
            color: isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0))),
      );
    }

    // ── Error ─────────────────────────────────────────────────────────────────
    if (_error != null || _card == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
        appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            elevation: 0),
        body: Center(child: Text(_error ?? 'Card not found.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF888899)))),
      );
    }

    // ── Premium lock screen — shown when card is locked ───────────────────────
    if (_isLocked) {
      return _buildLockedScreen(isDark);
    }

    final card  = _card!;
    final color = _catColor(card.category);

    // ── Normal card detail ────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildSliverAppBar(card, color, isDark)],
        body: Column(children: [
          _buildTabBar(color, isDark),
          Expanded(child: TabBarView(controller: _tabCtrl, children: [
            _buildCueCardTab(card, color, isDark),
            _buildAnswerTab(card, color, isDark),
            _buildVocabTab(card, color, isDark),
          ])),
          // ── Banner ad — auto-hidden for premium users ─────────────────
          const BannerAdWidget(),
        ]),
      ),
    );
  }

  // ── Premium lock screen ────────────────────────────────────────────────────
  Widget _buildLockedScreen(bool isDark) {
    final card = _card!;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          card.topic,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            const SizedBox(height: 20),

            // Lock icon
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFFFB300).withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.lock_rounded,
                  color: Color(0xFFFFB300), size: 44),
            ),
            const SizedBox(height: 28),

            // Title
            Text(
              'Premium Card',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            // Card topic preview
            Text(
              card.topic,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF8899AA)
                    : const Color(0xFF555577),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              'This cue card is part of the Premium collection '
              '(cards ${kFreeCardLimit + 1}–200+).\n'
              'Upgrade once to unlock all cards, Band 7–8 answers, '
              'and vocabulary forever.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: isDark
                    ? const Color(0xFF557799)
                    : const Color(0xFF888899),
              ),
            ),
            const SizedBox(height: 32),

            // What you get
            _buildLockedFeaturesList(isDark),
            const SizedBox(height: 32),

            // CTA button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/premium'),
                icon: const Icon(Icons.workspace_premium_rounded, size: 22),
                label: const Text('Unlock All Cards — ₹199'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  elevation: 4,
                  shadowColor: const Color(0xFFFFB300).withOpacity(0.4),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Fine print
            Text(
              'One-time payment · No subscription · No hidden fees',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF3A5570)
                    : const Color(0xFFAAAAAA),
              ),
            ),
            const SizedBox(height: 12),

            // Back button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Go back to card list',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildLockedFeaturesList(bool isDark) {
    const features = [
      (Icons.style_rounded,                'All 200+ cue cards unlocked'),
      (Icons.star_rounded,                 'Band 7–8 sample answers'),
      (Icons.spellcheck_rounded,           'Full vocabulary for every card'),
      (Icons.tips_and_updates_outlined,    'Speaking tips for every topic'),
      (Icons.all_inclusive_rounded,        'Lifetime access — pay once'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? []
            : [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )],
      ),
      child: Column(children: features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(f.$1, color: const Color(0xFFFFB300), size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(f.$2,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E))),
          ),
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF2E7D32), size: 18),
        ]),
      )).toList()),
    );
  }

  // ── Sliver app bar ─────────────────────────────────────────────────────────
  SliverAppBar _buildSliverAppBar(CueCard card, Color color, bool isDark) {
    return SliverAppBar(
      expandedHeight: 185,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0F1B2D) : color,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              key: ValueKey(_isBookmarked),
              color: Colors.white,
              size: 24,
            ),
          ),
          onPressed: _toggleBookmark,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0D1E30), const Color(0xFF142638)]
                  : [color, color.withOpacity(0.75)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(card.category.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('${card.vocabulary.length} vocab words',
                            style: const TextStyle(color: Colors.white70, fontSize: 10,
                                fontWeight: FontWeight.w500)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text('Card #${card.id}',
                        style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(card.topic, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17,
                            fontWeight: FontWeight.bold, height: 1.35)),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(Color color, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F1B2D) : Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: color,
        unselectedLabelColor: isDark ? const Color(0xFF557799) : const Color(0xFF888899),
        indicatorColor: color,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [Tab(text: 'Cue Card'), Tab(text: 'Answer'), Tab(text: 'Vocabulary')],
      ),
    );
  }

  // ── Tab 1: Cue Card ────────────────────────────────────────────────────────
  Widget _buildCueCardTab(CueCard card, Color color, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
            boxShadow: isDark ? [] : [BoxShadow(
                color: color.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.description_outlined, color: color, size: 20)),
              const SizedBox(width: 10),
              Text('Speaking Cue Card',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.timer_outlined, size: 13, color: Color(0xFFFFB300)),
                  SizedBox(width: 4),
                  Text('2 min', style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600, color: Color(0xFFFFB300))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Divider(color: color.withOpacity(0.12)),
            const SizedBox(height: 14),
            Text(card.topic, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                height: 1.4,
                color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E))),
            const SizedBox(height: 16),
            Text('You should say:', style: TextStyle(fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF8899AA) : const Color(0xFF555577))),
            const SizedBox(height: 10),
            ...List.generate(card.prompts.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 20, height: 20, margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.12), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${i + 1}', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: color))),
                const SizedBox(width: 10),
                Expanded(child: Text(card.prompts[i], style: TextStyle(
                    fontSize: 14, height: 1.45,
                    color: isDark ? const Color(0xFFCDD5E0) : const Color(0xFF333355)))),
              ]),
            )),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFFFB300)),
                const SizedBox(width: 6),
                Text('1 min prep  ·  2 min speaking',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFFB300) : const Color(0xFFE65100))),
              ]),
            ),
          ]),
        ),

        if (card.tips.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Speaking Tips', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E))),
          const SizedBox(height: 10),
          ...card.tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.tips_and_updates_outlined, size: 16, color: Color(0xFFFFB300)),
              const SizedBox(width: 8),
              Expanded(child: Text(tip, style: TextStyle(fontSize: 13, height: 1.45,
                  color: isDark ? const Color(0xFFCDD5E0) : const Color(0xFF333355)))),
            ]),
          )),
        ],

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/random-practice'),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Start Timed Practice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Tab 2: Answer ──────────────────────────────────────────────────────────
  Widget _buildAnswerTab(CueCard card, Color color, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.75)]),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star_rounded, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text('Band 7–8', style: TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showAnswer = !_showAnswer),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2E4A) : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(_showAnswer ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 15, color: color),
                const SizedBox(width: 5),
                Text(_showAnswer ? 'Hide Answer' : 'Reveal Answer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _showAnswer ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(card.bandAnswer, style: TextStyle(fontSize: 14.5, height: 1.75,
                  color: isDark ? const Color(0xFFCDD5E0) : const Color(0xFF1A1A2E))),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: card.bandAnswer));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Answer copied!'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy_rounded, size: 13, color: color),
                      const SizedBox(width: 5),
                      Text('Copy Answer', style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          secondChild: Container(
            width: double.infinity, padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.18)),
            ),
            child: Column(children: [
              Icon(Icons.lock_outline_rounded, size: 40, color: color.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text('Tap "Reveal Answer" to see\nthe Band 7–8 sample answer',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.5,
                      color: isDark ? const Color(0xFF557799) : const Color(0xFF888899))),
              const SizedBox(height: 4),
              Text('Try answering first for best results!',
                  style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic,
                      color: isDark ? const Color(0xFF3A5570) : const Color(0xFFAAAAAA))),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Tab 3: Vocabulary ──────────────────────────────────────────────────────
  Widget _buildVocabTab(CueCard card, Color color, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Key Vocabulary (${card.vocabulary.length} words)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E))),
        const SizedBox(height: 12),
        ...card.vocabulary.map((v) {
          final posColor = _posColors[v.partOfSpeech] ?? const Color(0xFF546E7A);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isDark ? [] : [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(v.word[0].toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(v.word, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                      color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: posColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(v.partOfSpeech, style: TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w600, color: posColor)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(v.meaning, style: TextStyle(fontSize: 12.5, height: 1.45,
                    color: isDark ? const Color(0xFF8899AA) : const Color(0xFF555577))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('"', style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.bold, color: color, height: 1)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(v.example, style: TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic, height: 1.4,
                        color: isDark ? const Color(0xFFCDD5E0) : const Color(0xFF333355)))),
                  ]),
                ),
              ])),
            ]),
          );
        }),
      ]),
    );
  }
}