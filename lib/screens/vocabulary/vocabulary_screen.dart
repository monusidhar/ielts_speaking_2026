import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../widgets/banner_ad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/vocabulary/vocabulary_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
//
// FREE users    → vocabulary from cards 1–kFreeCardLimit only
// PREMIUM users → vocabulary from all cards
// Pagination    → kPageSize words visible at a time, "Load More" at bottom
// ─────────────────────────────────────────────────────────────────────────────

const int _kPageSize = 30; // words loaded per page

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
Color _posColor(String pos) => _posColors[pos] ?? const Color(0xFF546E7A);

// ── Extended vocab entry that carries card category ───────────────────────────
class _VocabEntry {
  final VocabWord word;
  final String    cardCategory;
  const _VocabEntry({required this.word, required this.cardCategory});
}

// ─────────────────────────────────────────────────────────────────────────────
class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});
  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl   = TextEditingController();
  final ScrollController      _scrollCtrl   = ScrollController();

  // All words available to this user (free: 1–50, premium: all)
  List<_VocabEntry> _allWords    = [];
  // Total locked word count (for upsell banner)
  int               _lockedCount = 0;

  List<String>      _categories     = ['All'];
  String            _selectedCat    = 'All';
  String            _searchQuery    = '';
  int?              _expandedIndex;
  bool              _isLoading      = true;
  String?           _error;

  // ── Pagination ────────────────────────────────────────────────────────────
  int  _visibleCount = _kPageSize; // how many of _filtered are shown
  bool _isLoadingMore = false;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scrollCtrl.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Auto load-more when user scrolls near the bottom ─────────────────────
  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      _maybeLoadMore();
    }
  }

  void _maybeLoadMore() {
    final filtered = _filtered;
    if (_isLoadingMore) return;
    if (_visibleCount >= filtered.length) return;

    setState(() => _isLoadingMore = true);

    // Simulate a brief async pause so the indicator shows
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _visibleCount  = (_visibleCount + _kPageSize).clamp(0, filtered.length);
          _isLoadingMore = false;
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final isPremium = PrefsRepository.isPremium();
      final allCards  = await CueCardRepository.loadAll();
      final cats      = await CueCardRepository.getCategories();

      // Split cards into accessible vs locked for this user
      final accessibleCards = isPremium
          ? allCards
          : allCards.where((c) => c.id <= kFreeCardLimit).toList();

      final lockedCards = isPremium
          ? <dynamic>[]
          : allCards.where((c) => c.id > kFreeCardLimit).toList();

      // Flatten accessible words
      final entries = <_VocabEntry>[];
      for (final card in accessibleCards) {
        for (final word in card.vocabulary) {
          entries.add(_VocabEntry(word: word, cardCategory: card.category));
        }
      }

      // Count locked words for the upsell banner
      int lockedWordCount = 0;
      for (final card in lockedCards) {
        lockedWordCount += (card as dynamic).vocabulary.length as int;
      }

      if (mounted) {
        setState(() {
          _allWords    = entries;
          _lockedCount = lockedWordCount;
          _categories  = cats;
          _isLoading   = false;
        });
        _animCtrl.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error    = 'Failed to load vocabulary.';
          _isLoading = false;
        });
      }
    }
  }

  // ── Filtered list (full — pagination applied separately) ──────────────────
  List<_VocabEntry> get _filtered => _allWords.where((e) {
    final matchCat    = _selectedCat == 'All' || e.cardCategory == _selectedCat;
    final matchSearch = _searchQuery.isEmpty ||
        e.word.word.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        e.word.meaning.toLowerCase().contains(_searchQuery.toLowerCase());
    return matchCat && matchSearch;
  }).toList();

  // Visible slice of filtered list
  List<_VocabEntry> get _visibleWords {
    final f = _filtered;
    return f.take(_visibleCount.clamp(0, f.length)).toList();
  }

  // Reset pagination whenever search/category changes
  void _resetPagination() {
    setState(() {
      _visibleCount   = _kPageSize;
      _expandedIndex  = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final isPremium = PrefsRepository.isPremium();
    final filtered  = _filtered;
    final visible   = _visibleWords;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Vocabulary'),
        backgroundColor: isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${filtered.length} words',
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
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: isDark
                      ? const Color(0xFF4DB6FF)
                      : const Color(0xFF1565C0)))
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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            // +1 for the load-more / premium footer item
                            itemCount: visible.length + 1,
                            itemBuilder: (ctx, i) {
                              // ── Footer item ───────────────────────────
                              if (i == visible.length) {
                                return _buildListFooter(
                                    isDark, isPremium, filtered.length);
                              }

                              // ── Vocab card ────────────────────────────
                              final slideAnim = Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: _animCtrl,
                                  curve: Interval(
                                    (i * 0.04).clamp(0.0, 0.8),
                                    ((i * 0.04) + 0.4).clamp(0.0, 1.0),
                                    curve: Curves.easeOut,
                                  )));

                              final fadeAnim = Tween<double>(begin: 0, end: 1)
                                  .animate(CurvedAnimation(
                                      parent: _animCtrl,
                                      curve: Interval(
                                        (i * 0.04).clamp(0.0, 0.8),
                                        ((i * 0.04) + 0.4).clamp(0.0, 1.0),
                                        curve: Curves.easeOut,
                                      )));

                              return FadeTransition(
                                opacity: fadeAnim,
                                child: SlideTransition(
                                  position: slideAnim,
                                  child: _VocabCard(
                                    entry:      visible[i],
                                    isDark:     isDark,
                                    isExpanded: _expandedIndex == i,
                                    onTap: () => setState(() =>
                                        _expandedIndex =
                                            _expandedIndex == i ? null : i),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const BannerAdWidget(),
                ]),
    );
  }

  // ── List footer: load-more spinner / button + premium upsell ─────────────
  Widget _buildListFooter(
      bool isDark, bool isPremium, int totalFiltered) {
    final hasMore = _visibleCount < totalFiltered;

    return Column(children: [
      // ── Load more indicator / button ─────────────────────────────────────
      if (hasMore) ...[
        const SizedBox(height: 8),
        if (_isLoadingMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: isDark
                  ? const Color(0xFF4DB6FF)
                  : const Color(0xFF1565C0),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: OutlinedButton.icon(
              onPressed: _maybeLoadMore,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              label: Text(
                  'Load more  ·  ${totalFiltered - _visibleCount} remaining'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? const Color(0xFF4DB6FF)
                    : const Color(0xFF1565C0),
                side: BorderSide(
                    color: isDark
                        ? const Color(0xFF2A3E55)
                        : const Color(0xFFDDDDEE)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],

      // ── Premium upsell (free users only) ─────────────────────────────────
      if (!isPremium && _lockedCount > 0) ...[
        const SizedBox(height: 12),
        _buildPremiumUpsellCard(isDark),
      ],

      const SizedBox(height: 12),
    ]);
  }

  // ── Premium upsell card shown at the bottom of the list ──────────────────
  Widget _buildPremiumUpsellCard(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/premium'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
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
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text(
                'Unlock more vocabulary',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '$_lockedCount more words hidden behind Premium. '
                'Upgrade for ₹199 lifetime.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 12.5,
                    height: 1.45),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white70, size: 14),
        ]),
      ),
    );
  }

  Widget _buildError(bool isDark) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Color(0xFFC62828)),
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFF8899AA)
                      : const Color(0xFF555577))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error     = null;
              });
              _loadData();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ]),
      );

  // ── Search bar + category chips ───────────────────────────────────────────
  Widget _buildHeader(bool isDark, bool isPremium) {
    return Container(
      color: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      child: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) {
              setState(() => _searchQuery = v);
              _resetPagination();
            },
            style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E)),
            decoration: InputDecoration(
              hintText: 'Search words or meanings...',
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
                        _resetPagination();
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
                      width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Category chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat      = _categories[i];
              final selected = cat == _selectedCat;
              final color =
                  cat == 'All' ? const Color(0xFF1565C0) : _catColor(cat);
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedCat = cat);
                  _resetPagination();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? color
                        : (isDark
                            ? const Color(0xFF1A2E4A)
                            : Colors.white),
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
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : (isDark
                                  ? const Color(0xFF8899AA)
                                  : const Color(0xFF555577)))),
                ),
              );
            },
          ),
        ),

        // ── Free user: compact top banner ─────────────────────────────────
        if (!isPremium && _lockedCount > 0) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/premium'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(
                    isDark ? 0.12 : 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        const Color(0xFFFFB300).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.lock_rounded,
                    color: Color(0xFFFFB300), size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_lockedCount words locked behind Premium.',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFFFB300)
                            : const Color(0xFFE65100)),
                  ),
                ),
                Text(
                  'Unlock ₹199',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFFFB300)
                          : const Color(0xFFE65100)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 11, color: Color(0xFFFFB300)),
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
              size: 52,
              color: isDark
                  ? const Color(0xFF2A3E55)
                  : const Color(0xFFCCCCDD)),
          const SizedBox(height: 14),
          Text('No words found',
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
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// VOCAB CARD — expandable
// ─────────────────────────────────────────────────────────────────────────────
class _VocabCard extends StatelessWidget {
  final _VocabEntry  entry;
  final bool         isDark;
  final bool         isExpanded;
  final VoidCallback onTap;

  const _VocabCard({
    required this.entry,
    required this.isDark,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w        = entry.word;
    final catColor = _catColor(entry.cardCategory);
    final posColor = _posColor(w.partOfSpeech);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isExpanded
                    ? catColor.withOpacity(0.4)
                    : Colors.transparent,
                width: 1.5),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                        color: isExpanded
                            ? catColor.withOpacity(0.10)
                            : Colors.black.withOpacity(0.05),
                        blurRadius: isExpanded ? 14 : 8,
                        offset: const Offset(0, 2))
                  ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header row ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(children: [
                // Letter avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: catColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(w.word[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: catColor)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                        child: Text(w.word,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFE8EAF0)
                                    : const Color(0xFF1A1A2E))),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: w.word));
                          HapticFeedback.lightImpact();
                        },
                        child: Icon(Icons.copy_rounded,
                            size: 15,
                            color: isDark
                                ? const Color(0xFF3A5570)
                                : const Color(0xFFCCCCDD)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      _Chip(label: w.partOfSpeech, color: posColor),
                      const SizedBox(width: 6),
                      _Chip(label: entry.cardCategory, color: catColor),
                    ]),
                  ]),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: isDark
                            ? const Color(0xFF3A5570)
                            : const Color(0xFFCCCCDD))),
              ]),
            ),

            // ── Meaning (always visible) ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                w.meaning,
                maxLines: isExpanded ? 10 : 1,
                overflow: isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? const Color(0xFF8899AA)
                        : const Color(0xFF555577)),
              ),
            ),

            // ── Expanded: example sentence ─────────────────────────────
            if (isExpanded) ...[
              Divider(
                  height: 1,
                  color: isDark
                      ? const Color(0xFF253A4A)
                      : const Color(0xFFEEEEF5)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: catColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: Text('"',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: catColor,
                              height: 1)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Example',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: catColor,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(w.example,
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.55,
                                fontStyle: FontStyle.italic,
                                color: isDark
                                    ? const Color(0xFFCDD5E0)
                                    : const Color(0xFF1A1A2E))),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.tips_and_updates_outlined,
                          size: 15, color: Color(0xFFFFB300)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Use this word in your IELTS Speaking answer '
                          'to boost your vocabulary score.',
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: isDark
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFFE65100)),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Small colored chip ─────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.2)),
      );
}