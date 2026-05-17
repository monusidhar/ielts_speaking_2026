import 'package:flutter/material.dart';
import '../../data/repositories/speaking_question_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../widgets/banner_ad_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/speaking_practice/speaking_topics_screen.dart
//
// Lists Part 1 or Part 3 topics. User taps a topic → navigates to practice.
// ─────────────────────────────────────────────────────────────────────────────

class SpeakingTopicsScreen extends StatefulWidget {
  final String partLabel; // "Part 1" or "Part 3"
  const SpeakingTopicsScreen({super.key, required this.partLabel});
  @override
  State<SpeakingTopicsScreen> createState() => _SpeakingTopicsScreenState();
}

class _SpeakingTopicsScreenState extends State<SpeakingTopicsScreen> {
  List<SpeakingTopic> _topics = [];
  List<SpeakingTopic> _filtered = [];
  Set<int> _practicedIds = {};
  bool _isLoading = true;
  final _searchCtrl = TextEditingController();

  bool get _isPart1 => widget.partLabel == 'Part 1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final topics = _isPart1
        ? await SpeakingQuestionRepository.getPart1Topics()
        : await SpeakingQuestionRepository.getPart3Topics();
    final practiced = _isPart1
        ? PrefsRepository.getPart1PracticedIds()
        : PrefsRepository.getPart3PracticedIds();
    if (mounted) {
      setState(() {
        _topics = topics;
        _filtered = topics;
        _practicedIds = practiced;
        _isLoading = false;
      });
    }
  }

  void _refreshPracticed() {
    setState(() {
      _practicedIds = _isPart1
          ? PrefsRepository.getPart1PracticedIds()
          : PrefsRepository.getPart3PracticedIds();
    });
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = _topics;
      } else {
        _filtered = _topics.where((t) {
          if (t.topic.toLowerCase().contains(q)) return true;
          return t.questionTexts.any((q2) => q2.toLowerCase().contains(q));
        }).toList();
      }
    });
  }

  Color get _accentColor =>
      _isPart1 ? const Color(0xFF0288D1) : const Color(0xFF6A1B9A);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('${widget.partLabel} Questions'),
        backgroundColor: isDark ? const Color(0xFF0F1B2D) : _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: isDark ? const Color(0xFF4DB6FF) : _accentColor))
          : Column(children: [
              // ── Search bar ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: InputDecoration(
                    hintText: 'Search topics...',
                    prefixIcon: Icon(Icons.search_rounded,
                        color: isDark
                            ? const Color(0xFF557799)
                            : const Color(0xFF888899)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A2E4A) : Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              // ── Info banner ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(
                      _isPart1
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.forum_outlined,
                      color: _accentColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isPart1
                            ? '${_filtered.length} topics · Short answer questions · ~30 sec each'
                            : '${_filtered.length} topics · Discussion questions · ~45 sec each',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _accentColor),
                      ),
                    ),
                  ]),
                ),
              ),
              // ── Topic list ───────────────────────────────────────────
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text('No topics found',
                            style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? const Color(0xFF557799)
                                    : const Color(0xFF888899))))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) =>
                            _buildTopicCard(_filtered[i], isDark),
                      ),
              ),
              const BannerAdWidget(),
            ]),
    );
  }

  Widget _buildTopicCard(SpeakingTopic topic, bool isDark) {
    final isPracticed = _practicedIds.contains(topic.id);
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, '/speaking-practice', arguments: {
          'topic': topic,
          'partLabel': widget.partLabel,
        });
        _refreshPracticed();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentColor.withOpacity(0.12), width: 1),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${topic.id}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _accentColor),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.topic,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFE8EAF0)
                          : const Color(0xFF1A1A2E)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${topic.questions.length} questions',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF557799)
                          : const Color(0xFF888899)),
                ),
              ],
            ),
          ),
          if (isPracticed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.check_circle_rounded,
                  size: 20, color: const Color(0xFF2E7D32)),
            ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14,
              color:
                  isDark ? const Color(0xFF557799) : const Color(0xFFAAAAAA)),
        ]),
      ),
    );
  }
}
