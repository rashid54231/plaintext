import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0B0E14);
    const card = Color(0xFF131823);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Analytics',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.info_outline_rounded, size: 18, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          final all = taskProvider.allTasks;
          final completed = all.where((t) => t.isCompleted).length;
          final pending = all.where((t) => !t.isCompleted && !t.isOverdue).length;
          final overdue = all.where((t) => t.isOverdue).length;
          final total = all.length;

          final completionRate = total > 0 ? (completed / total) : 0.0;
          final onTimeRate = total > 0 ? (((total - overdue) / total) * 100).clamp(0.0, 100.0) : 100.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Slide 3: Card 1 - Weekly Task Completion Bar Chart with "All Months >"
                _buildWeeklyCompletionCard(all, card, textPrimary, textSecondary),
                const SizedBox(height: 16),

                // Slide 3: Card 2 - Split Row (Multi-color Donut Chart + Total Productivity Score)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildDonutChartCard(all, completed, pending, overdue, card, textPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: _buildProductivityScoreCard(completed, total, card, textPrimary, textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Slide 3: Card 3 - Overdue Task Tracker Pill Card
                _buildOverdueTrackerCard(overdue, card, textPrimary),
                const SizedBox(height: 16),

                // Slide 3: Card 4 - Monthly Trend Wave Line Chart
                _buildMonthlyTrendCard(all, card, textPrimary, textSecondary),
                const SizedBox(height: 20),

                // Slide 3: Floating Callout Highlight Badges
                _buildFloatingHighlightCards(completionRate, onTimeRate, card, textPrimary, textSecondary),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  // Slide 3: Card 1 - Weekly task completion with real data from Supabase
  Widget _buildWeeklyCompletionCard(List<Task> all, Color card, Color textPrimary, Color textSecondary) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final counts = List.filled(7, 0.0);

    for (final t in all) {
      if (t.isCompleted && t.completedDate != null) {
        final weekday = t.completedDate!.weekday; // 1 = Mon, 7 = Sun
        if (weekday >= 1 && weekday <= 7) {
          counts[weekday - 1] += 1.0;
        }
      } else {
        final weekday = t.dueDate.weekday;
        if (weekday >= 1 && weekday <= 7) {
          counts[weekday - 1] += 0.5; // scheduled weight
        }
      }
    }

    double maxVal = counts.fold(0.0, (prev, elem) => elem > prev ? elem : prev);
    if (maxVal < 5.0) maxVal = 5.0;

    final barGroups = List.generate(7, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: counts[i],
            gradient: const LinearGradient(
              colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly task completion',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Text(
                      'All Months >',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: maxVal > 10 ? (maxVal / 4).roundToDouble() : 2,
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: textSecondary),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              days[idx],
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: textSecondary, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 10 ? (maxVal / 4).roundToDouble() : 2,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: Colors.white.withValues(alpha: 0.06),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 3: Multi-color Donut Chart (Real dynamic category / status distribution)
  Widget _buildDonutChartCard(List<Task> all, int completed, int pending, int overdue, Color card, Color textPrimary) {
    final highCount = all.where((t) => t.priority == Priority.high).length;
    final inProgressCount = all.where((t) => !t.isCompleted && !t.isOverdue).length;

    List<PieChartSectionData> sections;
    if (all.isEmpty) {
      sections = [
        PieChartSectionData(value: 1, color: Colors.white12, showTitle: false, radius: 24),
      ];
    } else {
      sections = [
        PieChartSectionData(value: (completed > 0 ? completed : 0.1).toDouble(), color: const Color(0xFF10B981), showTitle: false, radius: 24),
        PieChartSectionData(value: (inProgressCount > 0 ? inProgressCount : 0.1).toDouble(), color: const Color(0xFF38BDF8), showTitle: false, radius: 24),
        PieChartSectionData(value: (overdue > 0 ? overdue : 0.1).toDouble(), color: const Color(0xFFEF4444), showTitle: false, radius: 24),
        PieChartSectionData(value: (highCount > 0 ? highCount : 0.1).toDouble(), color: const Color(0xFFF97316), showTitle: false, radius: 24),
        PieChartSectionData(value: (all.isNotEmpty ? all.length : 0.1).toDouble(), color: const Color(0xFF8B5CF6), showTitle: false, radius: 24),
      ];
    }

    return Container(
      height: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 105,
          height: 105,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 28,
              sections: sections,
            ),
          ),
        ),
      ),
    );
  }

  // Slide 3: Total Productivity Score Card (Dynamic percentage based on real completion)
  Widget _buildProductivityScoreCard(int completed, int total, Color card, Color textPrimary, Color textSecondary) {
    final score = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final scorePct = (score * 100).toInt();

    return Container(
      height: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total\nProductivity\nScore',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              height: 1.2,
            ),
          ),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: score,
                    strokeWidth: 6,
                    backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$scorePct%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Slide 3: Overdue task tracker pill card with real backend count
  Widget _buildOverdueTrackerCard(int overdue, Color card, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Overdue task tracker',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  '$overdue',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Slide 3: Monthly trend wave chart calculated from real task history
  Widget _buildMonthlyTrendCard(List<Task> all, Color card, Color textPrimary, Color textSecondary) {
    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      final monthOffset = DateTime.now().subtract(Duration(days: (6 - i) * 30));
      final countInMonth = all.where((t) {
        final date = t.completedDate ?? t.dueDate;
        return date.year == monthOffset.year && date.month == monthOffset.month;
      }).length;
      spots.add(FlSpot(i.toDouble(), countInMonth.toDouble()));
    }

    double maxY = spots.fold(0.0, (prev, s) => s.y > prev ? s.y : prev);
    if (maxY < 10) maxY = 10;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly trend',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  'Months >',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 10 ? (maxY / 3).roundToDouble() : 2,
                  getDrawingHorizontalLine: (v) => FlLine(color: Colors.white.withValues(alpha: 0.06)),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: maxY > 10 ? (maxY / 3).roundToDouble() : 2,
                      getTitlesWidget: (v, m) => Text(
                        v.toInt().toString(),
                        style: GoogleFonts.plusJakartaSans(fontSize: 10, color: textSecondary),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF38BDF8),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          const Color(0xFF818CF8).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Slide 3: Floating Highlight Cards with real completion rate and on-time rate
  Widget _buildFloatingHighlightCards(
    double completionRate,
    double onTimeRate,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    final compPct = (completionRate * 100).toInt();
    final onTimePct = onTimeRate.toInt();

    return Row(
      children: [
        // Completed Rate
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$compPct%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Completed',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_outward_rounded, color: Color(0xFF38BDF8), size: 26),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // On-Time Rate
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF38BDF8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'On-Time Rate',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        '$onTimePct%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}