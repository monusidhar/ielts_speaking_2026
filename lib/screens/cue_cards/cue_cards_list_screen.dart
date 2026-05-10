import 'package:flutter/material.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../widgets/banner_ad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/cue_cards/cue_cards_list_screen.dart
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

class CueCardsListScreen extends StatefulWidget {
  const CueCardsListScreen({super.key});
  @override
  State<CueCardsListScreen> createState() => _CueCardsListScreenState();
}

class _CueCardsListScreenState extends State<CueCardsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<CueCard> _allCards = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;
  bool _showScrollTop = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 300;
      if (show != _showScrollTop) setState(() => _showScrollTop = show);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final cards = await CueCardRepository.loadAll();
      debugPrint('✅ Total cards loaded: ${cards.length}'); // ADD THIS
      debugPrint('✅ isPremium: ${PrefsRepository.isPremium()}'); // ADD THIS
      final cats = await CueCardRepository.getCategories();
      if (mounted)
        setState(() {
          _allCards = cards;
          _categories = cats;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Failed to load. Please restart.';
          _isLoading = false;
        });
    }
  }

  List<CueCard> get _filtered => _allCards.where((c) {
        final matchCat =
            _selectedCategory == 'All' || c.category == _selectedCategory;
        final matchSearch = _searchQuery.isEmpty ||
            c.topic.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.category.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchCat && matchSearch;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;
    final isPremium = PrefsRepository.isPremium();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Cue Cards'),
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${filtered.length} cards',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _showScrollTop
          ? FloatingActionButton.small(
              onPressed: () => _scrollCtrl.animateTo(0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut),
              backgroundColor:
                  isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0),
              child: const Icon(Icons.keyboard_arrow_up_rounded,
                  color: Colors.white),
            )
          : null,
      body: _isLoading
          ? _buildLoader(isDark)
          : _error != null
              ? _buildError(isDark)
              : Column(children: [
                  _buildHeader(isDark, isPremium),
                  Expanded(
                    child: filtered.isEmpty
                        ? _buildEmpty(isDark)
                        : ListView.builder(
                            controller: _scrollCtrl,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) => _CueCardTile(
                              card: filtered[i],
                              isDark: isDark,
                              isPremium: isPremium,
                              onTap: () => Navigator.pushNamed(
                                  context, '/cue-card-detail',
                                  arguments: {'cardId': filtered[i].id}),
                            ),
                          ),
                  ),
                  // ── Banner ad — hidden for premium users automatically ────
                  const BannerAdWidget(),
                ]),
    );
  }

  Widget _buildLoader(bool isDark) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(
              color:
                  isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0)),
          const SizedBox(height: 14),
          Text('Loading cue cards...',
              style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899))),
        ]),
      );

  Widget _buildError(bool isDark) => Center(
        child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFC62828)),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF8899AA)
                          : const Color(0xFF555577))),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _loadData();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ])),
      );

  Widget _buildHeader(bool isDark, bool isPremium) {
    return Container(
      color: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      child: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E)),
            decoration: InputDecoration(
              hintText: 'Search cue cards...',
              prefixIcon: Icon(Icons.search_rounded,
                  size: 20,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFFAAAAAA)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18,
                          color: isDark
                              ? const Color(0xFF557799)
                              : const Color(0xFFAAAAAA)),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1A2E4A) : Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF4DB6FF)
                        : const Color(0xFF1565C0),
                    width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Category chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final selected = cat == _selectedCategory;
              final color =
                  cat == 'All' ? const Color(0xFF1565C0) : _catColor(cat);
              return GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? color
                        : (isDark ? const Color(0xFF1A2E4A) : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected
                            ? color
                            : (isDark
                                ? const Color(0xFF2A3E55)
                                : const Color(0xFFDDDDEE))),
                  ),
                  child: Text(cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF8899AA)
                                : const Color(0xFF555577)),
                      )),
                ),
              );
            },
          ),
        ),

        // ── Premium upsell banner — shown only to free users ──────────────
        if (!isPremium && _allCards.isNotEmpty) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/premium'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cards ${kFreeCardLimit + 1}–${_allCards.length} are Premium. '
                    'Unlock all for ₹199 lifetime.',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white70, size: 13),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildEmpty(bool isDark) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded,
            size: 56,
            color: isDark ? const Color(0xFF2A3E55) : const Color(0xFFCCCCDD)),
        const SizedBox(height: 16),
        Text('No cards found',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF557799)
                    : const Color(0xFF888899))),
        const SizedBox(height: 6),
        Text('Try a different search or category',
            style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFF3A5570)
                    : const Color(0xFFAAAAAA))),
      ]));
}

// ─────────────────────────────────────────────────────────────────────────────
// CUE CARD TILE
// ─────────────────────────────────────────────────────────────────────────────
class _CueCardTile extends StatelessWidget {
  final CueCard card;
  final bool isDark;
  final bool isPremium;
  final VoidCallback onTap;

  const _CueCardTile({
    required this.card,
    required this.isDark,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _catColor(card.category);
    final isLocked = !isPremium && card.id > kFreeCardLimit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
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
                      )
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── ID badge / lock icon ────────────────────────────────
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? const Color(0xFFFFB300).withOpacity(0.12)
                        : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: isLocked
                      ? const Icon(Icons.lock_rounded,
                          color: Color(0xFFFFB300), size: 20)
                      : Text('${card.id}',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                ),
                const SizedBox(width: 14),

                // ── Content ─────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.topic,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: isLocked
                              ? (isDark
                                  ? const Color(0xFF557799)
                                  : const Color(0xFFAAAAAA))
                              : (isDark
                                  ? const Color(0xFFE8EAF0)
                                  : const Color(0xFF1A1A2E)),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        card.promptPreview,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF557799)
                              : const Color(0xFF888899),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        // Category chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(card.category,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ),
                        const SizedBox(width: 6),
                        // Vocab count chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF253A4A)
                                : const Color(0xFFF0F0F8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${card.vocabulary.length} words',
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? const Color(0xFF557799)
                                      : const Color(0xFF888899))),
                        ),
                        // ── PRO badge for locked cards ──────────────────
                        if (isLocked) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PRO',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFFB300))),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Trailing icon ────────────────────────────────────────
                Icon(
                  isLocked
                      ? Icons.lock_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: isLocked ? 16 : 14,
                  color: isLocked
                      ? const Color(0xFFFFB300)
                      : (isDark
                          ? const Color(0xFF3A5570)
                          : const Color(0xFFCCCCDD)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
