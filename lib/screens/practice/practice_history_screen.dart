import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/repositories/practice_history_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FILE LOCATION: lib/screens/practice/practice_history_screen.dart
//
// Shows AI practice history with band score progress chart and session list.
// ─────────────────────────────────────────────────────────────────────────────

class PracticeHistoryScreen extends StatefulWidget {
  const PracticeHistoryScreen({super.key});
  @override
  State<PracticeHistoryScreen> createState() => _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends State<PracticeHistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  List<PracticeSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadSessions();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _loadSessions() {
    setState(() {
      _sessions = PracticeHistoryRepository.getAll();
    });
    _animCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1B2D) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Practice History'),
        backgroundColor:
            isDark ? const Color(0xFF0F1B2D) : const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _sessions.isEmpty
          ? _buildEmpty(isDark)
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildStatsRow(isDark)),
                  if (_sessions.length >= 2)
                    SliverToBoxAdapter(child: _buildChart(isDark)),
                  SliverToBoxAdapter(
                      child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text('Recent Sessions',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFE8EAF0)
                                : const Color(0xFF1A1A2E))),
                  )),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildSessionCard(_sessions[i], isDark),
                        childCount: _sessions.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.auto_awesome_rounded,
          size: 64,
          color: isDark ? const Color(0xFF2A3E55) : const Color(0xFFDDDDEE)),
      const SizedBox(height: 16),
      Text('No AI Practice Sessions Yet',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color:
                  isDark ? const Color(0xFF8899AA) : const Color(0xFF555577))),
      const SizedBox(height: 8),
      Text('Complete an AI practice session\nto see your progress here.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              color:
                  isDark ? const Color(0xFF557799) : const Color(0xFF888899))),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () =>
            Navigator.pushReplacementNamed(context, '/ai-practice'),
        icon: const Icon(Icons.mic_rounded, size: 18),
        label: const Text('Start AI Practice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ]));
  }

  Widget _buildStatsRow(bool isDark) {
    final avg = PracticeHistoryRepository.averageBand;
    final highest = PracticeHistoryRepository.highestBand;
    final count = _sessions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(children: [
        _StatTile(
            value: count.toString(),
            label: 'Sessions',
            icon: Icons.mic_rounded,
            color: const Color(0xFF1565C0),
            isDark: isDark),
        const SizedBox(width: 10),
        _StatTile(
            value: avg > 0 ? avg.toStringAsFixed(1) : '-',
            label: 'Avg Band',
            icon: Icons.analytics_rounded,
            color: const Color(0xFF6A1B9A),
            isDark: isDark),
        const SizedBox(width: 10),
        _StatTile(
            value: highest > 0 ? highest.toStringAsFixed(1) : '-',
            label: 'Highest',
            icon: Icons.star_rounded,
            color: const Color(0xFFFFB300),
            isDark: isDark),
      ]),
    );
  }

  Widget _buildChart(bool isDark) {
    // Show last 10 sessions in chronological order
    final chartData = _sessions.take(10).toList().reversed.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        height: 220,
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Band Score Progress',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFE8EAF0)
                        : const Color(0xFF1A1A2E))),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: isDark
                        ? const Color(0xFF2A3E55)
                        : const Color(0xFFEEEEF5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= chartData.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('#${idx + 1}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? const Color(0xFF557799)
                                      : const Color(0xFF888899))),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFF557799)
                                : const Color(0xFF888899)),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (chartData.length - 1).toDouble(),
                minY: 0,
                maxY: 9,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(chartData.length,
                        (i) => FlSpot(i.toDouble(), chartData[i].overallBand)),
                    isCurved: true,
                    color: const Color(0xFF6A1B9A),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: const Color(0xFF6A1B9A),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6A1B9A).withOpacity(0.1),
                    ),
                  ),
                  // Target band 7.0 line
                  LineChartBarData(
                    spots: [
                      FlSpot(0, 7),
                      FlSpot((chartData.length - 1).toDouble(), 7),
                    ],
                    isCurved: false,
                    color: const Color(0xFF2E7D32).withOpacity(0.5),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) {
                      if (spot.barIndex != 0) return null;
                      return LineTooltipItem(
                        'Band ${spot.y.toStringAsFixed(1)}',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSessionCard(PracticeSession session, bool isDark) {
    final color = _bandColor(session.overallBand);
    final dateStr =
        '${session.dateTime.day}/${session.dateTime.month}/${session.dateTime.year}';
    final timeStr = '${session.dateTime.hour.toString().padLeft(2, '0')}:'
        '${session.dateTime.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Row(children: [
        // Band circle
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
          ),
          alignment: Alignment.center,
          child: Text(session.overallBand.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.topic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE8EAF0)
                      : const Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Row(children: [
            _MiniChip(session.category, isDark),
            const SizedBox(width: 8),
            Text('$dateStr  $timeStr',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFF557799)
                        : const Color(0xFF888899))),
          ]),
        ])),
        Icon(Icons.chevron_right_rounded,
            size: 20,
            color: isDark ? const Color(0xFF446688) : const Color(0xFFCCCCCC)),
      ]),
    );
  }

  static Color _bandColor(double band) {
    if (band >= 7.5) return const Color(0xFF2E7D32);
    if (band >= 6.5) return const Color(0xFF1565C0);
    if (band >= 5.5) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }
}

class _StatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _StatTile(
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

class _MiniChip extends StatelessWidget {
  final String label;
  final bool isDark;
  const _MiniChip(this.label, this.isDark);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1B2D) : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF4DB6FF)
                    : const Color(0xFF1565C0))),
      );
}
