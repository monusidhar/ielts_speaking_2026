import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../widgets/banner_ad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/bookmarks/bookmark_screen.dart
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

class BookmarkScreen extends StatefulWidget {
  const BookmarkScreen({super.key});
  @override
  State<BookmarkScreen> createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen>
    with SingleTickerProviderStateMixin {

  final TextEditingController _searchCtrl = TextEditingController();

  List<CueCard> _bookmarkedCards = [];
  List<CueCard> _displayCards    = [];   // after search filter
  String        _searchQuery     = '';
  bool          _isLoading       = true;

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _loadBookmarks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Load bookmarked cards from prefs + JSON ────────────────────────────────
  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    try {
      final ids   = PrefsRepository.getBookmarkedIds();
      final all   = await CueCardRepository.loadAll();
      // keep original JSON order but only bookmarked ones
      final cards = all.where((c) => ids.contains(c.id)).toList();
      if (mounted) {
        setState(() {
          _bookmarkedCards = cards;
          _applySearch();
          _isLoading = false;
        });
        _animCtrl.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _displayCards = List.from(_bookmarkedCards);
    } else {
      final q = _searchQuery.toLowerCase();
      _displayCards = _bookmarkedCards
          .where((c) =>
      c.topic.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q))
          .toList();
    }
  }

  // ── Remove single bookmark (with undo) ────────────────────────────────────
  Future<void> _removeBookmark(CueCard card) async {
    // Remove from both lists immediately for snappy UI
    setState(() {
      _bookmarkedCards.removeWhere((c) => c.id == card.id);
      _displayCards.removeWhere((c) => c.id == card.id);
    });

    // Persist
    await PrefsRepository.removeBookmark(card.id);
    HapticFeedback.lightImpact();

    if (!mounted) return;

    // Undo snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${card.topic.length > 35
            ? "${card.topic.substring(0, 35)}..." : card.topic}"'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await PrefsRepository.toggleBookmark(card.id); // add back
            _loadBookmarks();
          },
        ),
      ),
    );
  }

  // ── Clear all bookmarks ────────────────────────────────────────────────────
  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Clear All Bookmarks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E))),
          content: Text('Remove all ${_bookmarkedCards.length} bookmarks? This cannot be undone.',
              style: TextStyle(fontSize: 13,
                  color: isDark ? const Color(0xFF8899AA) : const Color(0xFF555577))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await PrefsRepository.clearAllBookmarks();
      _loadBookmarks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Bookmarks'),
          if (_bookmarkedCards.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('${_bookmarkedCards.length}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        backgroundColor:
        isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_bookmarkedCards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear All',
              onPressed: _clearAll,
            ),
        ],
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(
          color: isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0)))
          : Column(children: [
        if (_bookmarkedCards.isNotEmpty) _buildSearchBar(isDark),
        Expanded(
          child: _bookmarkedCards.isEmpty
              ? _buildEmptyState(isDark)
              : _displayCards.isEmpty
              ? _buildNoResults(isDark)
              : _buildList(isDark),
        ),
        // ── Banner ad — auto-hidden for premium users ──────────────
        const BannerAdWidget(),
      ]),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() { _searchQuery = v; _applySearch(); }),
        style: TextStyle(fontSize: 14,
            color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E)),
        decoration: InputDecoration(
          hintText: 'Search bookmarks...',
          prefixIcon: Icon(Icons.search_rounded, size: 20,
              color: isDark ? const Color(0xFF557799) : const Color(0xFFAAAAAA)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
              icon: Icon(Icons.close_rounded, size: 18,
                  color: isDark ? const Color(0xFF557799) : const Color(0xFFAAAAAA)),
              onPressed: () {
                _searchCtrl.clear();
                setState(() { _searchQuery = ''; _applySearch(); });
              })
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: isDark ? const Color(0xFF4DB6FF) : const Color(0xFF1565C0),
                width: 1.5),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  // ── Bookmarks list ─────────────────────────────────────────────────────────
  Widget _buildList(bool isDark) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _displayCards.length,
      itemBuilder: (ctx, i) {
        final card      = _displayCards[i];
        final slideAnim = Tween<Offset>(
          begin: const Offset(0, 0.15), end: Offset.zero,
        ).animate(CurvedAnimation(parent: _animCtrl,
            curve: Interval((i * 0.08).clamp(0.0, 0.8),
                ((i * 0.08) + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut)));
        final fadeAnim = Tween<double>(begin: 0, end: 1)
            .animate(CurvedAnimation(parent: _animCtrl,
            curve: Interval((i * 0.08).clamp(0.0, 0.8),
                ((i * 0.08) + 0.4).clamp(0.0, 1.0), curve: Curves.easeOut)));

        return FadeTransition(
          opacity: fadeAnim,
          child: SlideTransition(
            position: slideAnim,
            child: _SwipeToDelete(
              key: ValueKey(card.id),
              onDelete: () => _removeBookmark(card),
              child: _BookmarkTile(
                card:   card,
                isDark: isDark,
                onTap:  () => Navigator.pushNamed(context, '/cue-card-detail',
                    arguments: {'cardId': card.id}),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Empty: no bookmarks at all ─────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bookmark_border_rounded, size: 64,
              color: isDark ? const Color(0xFF2A3E55) : const Color(0xFFCCCCDD)),
          const SizedBox(height: 18),
          Text('No Bookmarks Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF557799) : const Color(0xFF888899))),
          const SizedBox(height: 8),
          Text('Tap the bookmark icon on any cue card to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.55,
                  color: isDark ? const Color(0xFF3A5570) : const Color(0xFFAAAAAA))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/cue-cards'),
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: const Text('Browse Cue Cards'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Empty: search returned nothing ────────────────────────────────────────
  Widget _buildNoResults(bool isDark) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded, size: 52,
            color: isDark ? const Color(0xFF2A3E55) : const Color(0xFFCCCCDD)),
        const SizedBox(height: 14),
        Text('No results for "$_searchQuery"',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF557799) : const Color(0xFF888899))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SWIPE TO DELETE WRAPPER
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeToDelete extends StatelessWidget {
  final Widget    child;
  final VoidCallback onDelete;
  const _SwipeToDelete({required this.child, required this.onDelete, super.key});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: const Color(0xFFC62828),
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_rounded, color: Colors.white, size: 24),
          SizedBox(height: 4),
          Text('Remove', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKMARK TILE
// ─────────────────────────────────────────────────────────────────────────────
class _BookmarkTile extends StatelessWidget {
  final CueCard      card;
  final bool         isDark;
  final VoidCallback onTap;
  const _BookmarkTile({required this.card, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _catColor(card.category);
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
              border: Border(left: BorderSide(color: color, width: 4)),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withOpacity(0.05),
                    blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(card.category,
                        style: TextStyle(fontSize: 10.5,
                            fontWeight: FontWeight.w600, color: color)),
                  ),
                  const SizedBox(height: 8),
                  // Topic
                  Text(card.topic,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35,
                          color: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF1A1A2E))),
                  const SizedBox(height: 5),
                  // Prompt preview
                  Text(card.promptPreview,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5,
                          color: isDark ? const Color(0xFF557799) : const Color(0xFF888899))),
                ])),
                const SizedBox(width: 12),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bookmark_rounded, color: color, size: 22),
                  const SizedBox(height: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 13,
                      color: isDark ? const Color(0xFF3A5570) : const Color(0xFFCCCCDD)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}