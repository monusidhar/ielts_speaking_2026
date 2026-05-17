import 'package:flutter/material.dart';
import '../../data/repositories/cue_card_repository.dart';
import '../../data/repositories/prefs_repository.dart';
import '../../data/repositories/practice_history_repository.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/update_service.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/home/home_screen.dart
//
// FIX: Stats now refresh automatically every time HomeScreen becomes visible
// again — using RouteAware. No matter which screen the user came from,
// the bookmark/practiced counts will always be up-to-date.
// ─────────────────────────────────────────────────────────────────────────────

// ── Global RouteObserver — register in main.dart MaterialApp ─────────────────
// Add this line to your MaterialApp in main.dart:
//   navigatorObservers: [homeRouteObserver],
final RouteObserver<ModalRoute<void>> homeRouteObserver =
    RouteObserver<ModalRoute<void>>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  late AnimationController _animCtrl;
  late List<Animation<double>> _fadeAnims;

  int _totalCards = 0;
  int _practiced = 0;
  int _bookmarked = 0;
  bool _isLoading = true;

  // ── Daily AI Question ─────────────────────────────────────────────────
  String? _dailyQuestion;
  String _dailyQuestionPart = 'Part 1';
  bool _dailyQuestionLoading = false;
  // ── Streak, Target, Weak Area ───────────────────────────────────────
  int _streak = 0;
  bool _practicedToday = false;
  double? _targetBand;
  int? _daysUntilExam;
  String? _weakestArea;
  double? _weakestScore;
  final List<String> _tips = [
    'Use a variety of tenses — past, present perfect, and conditional — to show grammatical range.',
    'Open with a strong topic sentence and end with a personal opinion or reflection.',
    'Avoid repeating the same words. Use synonyms and paraphrases to show lexical resource.',
    'Practise speaking for exactly 2 minutes every day to build your internal timer.',
    'Use discourse markers like "Furthermore", "In contrast", and "What is more" to sound fluent.',
    'Describe emotions, not just facts — examiners reward personal connection to your topic.',
    'Record yourself speaking and listen back to spot pronunciation and fluency issues.',
  ];
  String get _dailyTip => _tips[DateTime.now().day % _tips.length];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnims = List.generate(
        9,
        (i) => Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
            parent: _animCtrl,
            curve:
                Interval(i * 0.08, (i * 0.08) + 0.5, curve: Curves.easeOut))));
    _loadAll();
    UpdateService.checkForUpdate(); // Fire-and-forget: Play Store update check
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route events — this is what makes refresh automatic
    homeRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    _animCtrl.dispose();
    super.dispose();
  }

  // ── RouteAware: called every time this screen comes back into view ─────────
  @override
  void didPopNext() {
    // User returned from ANY screen — refresh stats immediately
    _refreshStats();
  }

  // ── First load: JSON + SharedPreferences ──────────────────────────────────
  Future<void> _loadAll() async {
    try {
      final cards = await CueCardRepository.loadAll();
      if (mounted) {
        setState(() {
          _totalCards = cards.length;
          _practiced = PrefsRepository.getPracticedUniqueCount();
          _bookmarked = PrefsRepository.getBookmarkedCount();
          _streak = PrefsRepository.getStreakCount();
          _practicedToday = PrefsRepository.hasPracticedToday();
          _targetBand = PrefsRepository.getTargetBand();
          _daysUntilExam = PrefsRepository.getDaysUntilExam();
          _computeWeakArea();
          _isLoading = false;
        });
        _animCtrl.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
    _loadDailyQuestion();
  }

  /// Load daily AI question (from cache or API)
  Future<void> _loadDailyQuestion() async {
    // Check cache first
    final cached = PrefsRepository.getDailyQuestion();
    if (cached != null) {
      if (mounted) {
        setState(() {
          _dailyQuestion = cached;
          _dailyQuestionPart = PrefsRepository.getDailyQuestionPart();
        });
      }
      return;
    }

    // Fetch from AI
    if (!AiService.isConfigured) return;
    if (mounted) setState(() => _dailyQuestionLoading = true);

    try {
      final result = await AiService.generateDailyQuestion();
      await PrefsRepository.saveDailyQuestion(
          result['question']!, result['part']!);
      if (mounted) {
        setState(() {
          _dailyQuestion = result['question'];
          _dailyQuestionPart = result['part']!;
          _dailyQuestionLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dailyQuestionLoading = false);
    }
  }

  // ── Fast refresh: SharedPreferences only (no JSON re-load needed) ─────────
  void _refreshStats() {
    if (mounted) {
      setState(() {
        _practiced = PrefsRepository.getPracticedUniqueCount();
        _bookmarked = PrefsRepository.getBookmarkedCount();
        _streak = PrefsRepository.getStreakCount();
        _practicedToday = PrefsRepository.hasPracticedToday();
        _targetBand = PrefsRepository.getTargetBand();
        _daysUntilExam = PrefsRepository.getDaysUntilExam();
        _computeWeakArea();
      });
    }
  }

  void _computeWeakArea() {
    final sessions = PracticeHistoryRepository.getAll();
    if (sessions.length < 3) {
      _weakestArea = null;
      _weakestScore = null;
      return;
    }
    // Use last 10 sessions max for recent performance
    final recent = sessions.take(10).toList();
    final avgFluency =
        recent.map((s) => s.fluencyBand).reduce((a, b) => a + b) /
            recent.length;
    final avgLexical =
        recent.map((s) => s.lexicalBand).reduce((a, b) => a + b) /
            recent.length;
    final avgGrammar =
        recent.map((s) => s.grammarBand).reduce((a, b) => a + b) /
            recent.length;
    final avgPronunciation =
        recent.map((s) => s.pronunciationBand).reduce((a, b) => a + b) /
            recent.length;

    final scores = {
      'Fluency': avgFluency,
      'Lexical Resource': avgLexical,
      'Grammar': avgGrammar,
      'Pronunciation': avgPronunciation,
    };
    final weakest = scores.entries.reduce((a, b) => a.value <= b.value ? a : b);
    _weakestArea = weakest.key;
    _weakestScore = weakest.value;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isDark)),
            SliverToBoxAdapter(
                child: _FadeSection(
                    anim: _fadeAnims[0], child: _buildStreakAndGoal(isDark))),
            SliverToBoxAdapter(
                child: _FadeSection(
                    anim: _fadeAnims[1], child: _buildStats(isDark))),
            SliverToBoxAdapter(
                child: _FadeSection(
                    anim: _fadeAnims[2], child: _buildQuickActions(isDark))),
            SliverToBoxAdapter(
                child: _FadeSection(
                    anim: _fadeAnims[3], child: _buildExploreGrid(isDark))),
            SliverToBoxAdapter(
                child: _FadeSection(
                    anim: _fadeAnims[4], child: _buildDailyQuestion(isDark))),
            if (_weakestArea != null)
              SliverToBoxAdapter(
                  child: _FadeSection(
                      anim: _fadeAnims[5], child: _buildWeakAreaCard(isDark))),
            SliverToBoxAdapter(
                child: _FadeSection(
                    anim: _fadeAnims[6], child: _buildDailyTip(isDark))),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D1E30), const Color(0xFF142638)]
              : [const Color(0xFF1565C0), const Color(0xFF1976D2)],
        ),
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('IE',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              const SizedBox(width: 10),
              const Text('IELTS Speaking 2026',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.info_outline_rounded,
                    color: Colors.white70, size: 22),
                onPressed: () => Navigator.pushNamed(context, '/about'),
              ),
            ]),
            const SizedBox(height: 20),
            const Text('Ready to Practice?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Master IELTS Speaking · Achieve Band 7+',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/cue-cards'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.search_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  const Text('Search cue cards...',
                      style: TextStyle(color: Colors.white60, fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_isLoading ? '...' : '$_totalCards cards',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildStats(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(children: [
        _StatCard(
            value: _isLoading ? '...' : '$_totalCards',
            label: 'Total Cards',
            icon: Icons.library_books_rounded,
            color: const Color(0xFF1565C0),
            isDark: isDark),
        const SizedBox(width: 10),
        _StatCard(
            value: '$_practiced',
            label: 'Practiced',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF2E7D32),
            isDark: isDark),
        const SizedBox(width: 10),
        _StatCard(
            value: '$_bookmarked',
            label: 'Bookmarked',
            icon: Icons.bookmark_rounded,
            color: const Color(0xFFE65100),
            isDark: isDark),
      ]),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Actions',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _ActionButton(
            label: 'Random Practice',
            icon: Icons.shuffle_rounded,
            colors: [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)],
            onTap: () => Navigator.pushNamed(context, '/random-practice'),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: _ActionButton(
            label: 'All Cue Cards',
            icon: Icons.grid_view_rounded,
            colors: [const Color(0xFF1565C0), const Color(0xFF1976D2)],
            onTap: () => Navigator.pushNamed(context, '/cue-cards'),
          )),
        ]),
        const SizedBox(height: 12),
        // ── Full Mock Interview ───────────────────────────────────────
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/mock-interview-intro');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A1B9A).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.record_voice_over_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      const Text('Full Mock Interview',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('NEW',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Part 1 + Part 2 + Part 3 • AI Band Score',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                  ])),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.7), size: 16),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // ── AI Speaking Coach ─────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/ai-practice');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8F00), Color(0xFFFFB300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      const Text('AI Speaking Coach',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PRO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      PrefsRepository.isPremium()
                          ? 'Speak & get AI band score feedback'
                          : '5 free AI practices/day • Upgrade for more',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                  ])),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.7), size: 16),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildExploreGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Explore',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE8EAF0)
                    : const Color(0xFF1A1A2E))),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: [
            _ExploreCard(
                label: 'Bookmarks',
                icon: Icons.bookmark_rounded,
                color: const Color(0xFFE65100),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/bookmarks')),
            _ExploreCard(
                label: 'Vocabulary',
                icon: Icons.spellcheck_rounded,
                color: const Color(0xFF00695C),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/vocabulary')),
            _ExploreCard(
                label: 'Remove Ads',
                icon: Icons.workspace_premium_rounded,
                color: const Color(0xFFFFB300),
                isDark: isDark,
                showPro: true,
                onTap: () => Navigator.pushNamed(context, '/premium')),
            _ExploreCard(
                label: 'Privacy',
                icon: Icons.privacy_tip_outlined,
                color: const Color(0xFF455A64),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/privacy')),
            _ExploreCard(
                label: isDark ? 'Light Mode' : 'Dark Mode',
                icon:
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: const Color(0xFF37474F),
                isDark: isDark,
                onTap: () => IELTSSpeakingApp.toggleTheme(!isDark)),
            _ExploreCard(
                label: 'About App',
                icon: Icons.info_outline_rounded,
                color: const Color(0xFF1565C0),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/about')),
          ],
        ),
      ]),
    );
  }

  Widget _buildDailyQuestion(bool isDark) {
    // Don't show if no question loaded yet and not loading
    if (_dailyQuestion == null && !_dailyQuestionLoading) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1A3050), const Color(0xFF1A2E4A)]
                : [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? const Color(0xFF4DB6FF).withOpacity(0.2)
                : const Color(0xFF1565C0).withOpacity(0.15),
          ),
        ),
        child: _dailyQuestionLoading
            ? Row(children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark
                        ? const Color(0xFF4DB6FF)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Generating today\'s question...',
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF8899AA)
                            : const Color(0xFF555577))),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF4DB6FF).withOpacity(0.15)
                            : const Color(0xFF1565C0).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.psychology_rounded,
                          color: isDark
                              ? const Color(0xFF4DB6FF)
                              : const Color(0xFF1565C0),
                          size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily AI Question',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFF4DB6FF)
                                      : const Color(0xFF1565C0),
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF4DB6FF).withOpacity(0.1)
                                  : const Color(0xFF1565C0).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(_dailyQuestionPart,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF4DB6FF)
                                        : const Color(0xFF1565C0))),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    _dailyQuestion ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFE8EAF0)
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      if (PrefsRepository.isPremium() ||
                          PrefsRepository.canUseAi()) {
                        Navigator.pushNamed(
                          context,
                          '/daily-question-practice',
                          arguments: {
                            'question': _dailyQuestion!,
                            'partType': _dailyQuestionPart,
                          },
                        );
                      } else {
                        Navigator.pushNamed(context, '/premium');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF4DB6FF)
                            : const Color(0xFF1565C0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.mic_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          PrefsRepository.isPremium()
                              ? 'Practice with AI'
                              : 'Practice with AI (Free)',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAK + TARGET BAND + EXAM COUNTDOWN
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStreakAndGoal(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(children: [
        // ── Streak Card ──────────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: () {
              // Visual feedback only — streak is automatic
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_practicedToday
                    ? 'Great job! You practiced today.'
                    : 'Practice today to keep your streak!'),
                duration: const Duration(seconds: 2),
              ));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _streak > 0
                      ? [const Color(0xFFFF6D00), const Color(0xFFFF9100)]
                      : isDark
                          ? [const Color(0xFF1A2E4A), const Color(0xFF1A2E4A)]
                          : [Colors.white, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark || _streak == 0
                    ? []
                    : [
                        BoxShadow(
                            color: const Color(0xFFFF6D00).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(_streak > 0 ? '🔥' : '💤',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text('$_streak',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _streak > 0
                                ? Colors.white
                                : isDark
                                    ? const Color(0xFFCDD5E0)
                                    : const Color(0xFF1A1A2E))),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    _streak > 0
                        ? 'Day streak${_practicedToday ? ' ✓' : ''}'
                        : 'No streak yet',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _streak > 0
                            ? Colors.white.withOpacity(0.85)
                            : isDark
                                ? const Color(0xFF557799)
                                : const Color(0xFF888899)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // ── Target Band + Exam Card ──────────────────────────────────────
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () => _showGoalDialog(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
              ),
              child: _targetBand != null || _daysUntilExam != null
                  ? Row(children: [
                      if (_targetBand != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.flag_rounded,
                              color: Color(0xFF1565C0), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Target',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF557799)
                                          : const Color(0xFF888899))),
                              Text('Band ${_targetBand!.toStringAsFixed(1)}',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? const Color(0xFFE8EAF0)
                                          : const Color(0xFF1A1A2E))),
                            ]),
                      ],
                      if (_targetBand != null && _daysUntilExam != null)
                        const SizedBox(width: 16),
                      if (_daysUntilExam != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _daysUntilExam! <= 7
                                ? const Color(0xFFC62828).withOpacity(0.1)
                                : const Color(0xFF2E7D32).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.calendar_today_rounded,
                              color: _daysUntilExam! <= 7
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF2E7D32),
                              size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exam in',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF557799)
                                          : const Color(0xFF888899))),
                              Text(
                                  _daysUntilExam! > 0
                                      ? '$_daysUntilExam days'
                                      : _daysUntilExam == 0
                                          ? 'Today!'
                                          : 'Passed',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _daysUntilExam! <= 7
                                          ? const Color(0xFFC62828)
                                          : isDark
                                              ? const Color(0xFFE8EAF0)
                                              : const Color(0xFF1A1A2E))),
                            ]),
                      ],
                    ])
                  : Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.flag_rounded,
                            color: Color(0xFF1565C0), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Set your target band & exam date',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFF8899AA)
                                    : const Color(0xFF555577))),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: isDark
                              ? const Color(0xFF557799)
                              : const Color(0xFFAAAAAA)),
                    ]),
            ),
          ),
        ),
      ]),
    );
  }

  void _showGoalDialog() {
    double selectedBand = _targetBand ?? 7.0;
    DateTime? selectedDate;
    final examDateStr = PrefsRepository.getExamDate();
    if (examDateStr != null) {
      try {
        selectedDate = DateTime.parse(examDateStr);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: const Text('Set Your Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Band Score',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: selectedBand,
                    min: 5.0,
                    max: 9.0,
                    divisions: 8,
                    label: selectedBand.toStringAsFixed(1),
                    onChanged: (v) => setDialogState(() => selectedBand = v),
                  ),
                ),
                Text(selectedBand.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 20),
              const Text('Exam Date (optional)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate ??
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Tap to select date',
                    style: TextStyle(
                        fontSize: 14,
                        color: selectedDate != null ? null : Colors.grey),
                  ),
                ),
              ),
              if (selectedDate != null)
                TextButton(
                  onPressed: () => setDialogState(() => selectedDate = null),
                  child: const Text('Clear exam date',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await PrefsRepository.setTargetBand(selectedBand);
                if (selectedDate != null) {
                  final ds =
                      '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                  await PrefsRepository.setExamDate(ds);
                } else {
                  await PrefsRepository.clearExamDate();
                }
                if (mounted) {
                  setState(() {
                    _targetBand = selectedBand;
                    _daysUntilExam = PrefsRepository.getDaysUntilExam();
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEAK AREA ANALYSIS CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWeakAreaCard(bool isDark) {
    if (_weakestArea == null) return const SizedBox.shrink();

    final color = switch (_weakestArea) {
      'Fluency' => const Color(0xFF6A1B9A),
      'Lexical Resource' => const Color(0xFF00695C),
      'Grammar' => const Color(0xFFE65100),
      'Pronunciation' => const Color(0xFF0277BD),
      _ => const Color(0xFF1565C0),
    };

    final icon = switch (_weakestArea) {
      'Fluency' => Icons.speed_rounded,
      'Lexical Resource' => Icons.spellcheck_rounded,
      'Grammar' => Icons.edit_note_rounded,
      'Pronunciation' => Icons.record_voice_over_rounded,
      _ => Icons.analytics_rounded,
    };

    final tip = switch (_weakestArea) {
      'Fluency' => 'Try speaking non-stop for 1 minute on any topic daily.',
      'Lexical Resource' =>
        'Learn 3 new topic-specific words every day and use them.',
      'Grammar' => 'Practice using past perfect and conditionals in answers.',
      'Pronunciation' =>
        'Record yourself and compare with native speaker audio.',
      _ => 'Keep practicing to improve this area.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Focus Area',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Avg ${_weakestScore!.toStringAsFixed(1)}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ),
              ]),
              const SizedBox(height: 4),
              Text('$_weakestArea needs work',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFE8EAF0)
                          : const Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              Text(tip,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: isDark
                          ? const Color(0xFFCDD5E0)
                          : const Color(0xFF555577))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildDailyTip(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
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
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.lightbulb_rounded,
                  color: Color(0xFFFFB300), size: 22)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Daily Tip',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFB300),
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(_dailyTip,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.55,
                        color: isDark
                            ? const Color(0xFFCDD5E0)
                            : const Color(0xFF333355))),
              ])),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _FadeSection extends StatelessWidget {
  final Animation<double> anim;
  final Widget child;
  const _FadeSection({required this.anim, required this.child});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: anim,
        builder: (_, __) => Opacity(
            opacity: anim.value,
            child: Transform.translate(
                offset: Offset(0, 18 * (1 - anim.value)), child: child)),
      );
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _StatCard(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color,
      required this.isDark});
  @override
  Widget build(BuildContext context) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10.5,
                  color: isDark
                      ? const Color(0xFF557799)
                      : const Color(0xFF888899))),
        ]),
      ));
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.colors,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: colors[0].withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('Tap to start',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 11)),
        ]),
      ));
}

class _ExploreCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool showPro;
  final VoidCallback onTap;
  const _ExploreCard(
      {required this.label,
      required this.icon,
      required this.color,
      required this.isDark,
      required this.onTap,
      this.showPro = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Stack(children: [
          Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22)),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCDD5E0)
                        : const Color(0xFF333355))),
          ])),
          if (showPro)
            Positioned(
                top: 8,
                right: 8,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFB300),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('PRO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)))),
        ]),
      ));
}
