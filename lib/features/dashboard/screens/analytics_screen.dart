import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.background;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
//
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, _) {
          final all = taskProvider.allTasks;
          final completed = all.where((t) => t.isCompleted).length;
          final pending =
              all.where((t) => !t.isCompleted && !t.isOverdue).length;
          final overdue = all.where((t) => t.isOverdue).length;
          final total = all.length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(
                  total, completed, pending, overdue, card, textPrimary, textSecondary, isDark),
                const SizedBox(height: 24),
                _buildPieChart(completed, pending, overdue, total, card, textPrimary),
                const SizedBox(height: 24),
                _buildPriorityBreakdown(all, card, textPrimary, textSecondary),
                const SizedBox(height: 24),
                _buildCategoryBreakdown(all, card, textPrimary, textSecondary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(int total, int completed, int pending, int overdue,
      Color card, Color textPrimary, Color textSecondary, bool isDark) {
    final rate = total > 0 ? (completed / total * 100).toInt() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard('Total', '$total', Icons.assignment_rounded, AppColors.primary, card)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Completion', '$rate%', Icons.percent_rounded, AppColors.success, card)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard('Pending', '$pending', Icons.pending_rounded, AppColors.warning, card)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Overdue', '$overdue', Icons.warning_rounded, AppColors.error, card)),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(int completed, int pending, int overdue, int total,
      Color card, Color textPrimary) {
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Task Distribution', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 50,
                sections: [
                  if (completed > 0)
                    PieChartSectionData(
                      value: completed.toDouble(),
                      color: AppColors.success,
                      title: '$completed',
                      radius: 60,
                      titleStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (pending > 0)
                    PieChartSectionData(
                      value: pending.toDouble(),
                      color: AppColors.warning,
                      title: '$pending',
                      radius: 60,
                      titleStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  if (overdue > 0)
                    PieChartSectionData(
                      value: overdue.toDouble(),
                      color: AppColors.error,
                      title: '$overdue',
                      radius: 60,
                      titleStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _legend('Completed', AppColors.success),
              _legend('Pending', AppColors.warning),
              _legend('Overdue', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildPriorityBreakdown(List<Task> tasks, Color card, Color textPrimary, Color textSecondary) {
    final high = tasks.where((t) => t.priority == Priority.high).length;
    final medium = tasks.where((t) => t.priority == Priority.medium).length;
    final low = tasks.where((t) => t.priority == Priority.low).length;
    final total = tasks.length;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Priority Breakdown', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 16),
          _progressBar('High', high, total, AppColors.highPriority, textSecondary),
          const SizedBox(height: 12),
          _progressBar('Medium', medium, total, AppColors.mediumPriority, textSecondary),
          const SizedBox(height: 12),
          _progressBar('Low', low, total, AppColors.lowPriority, textSecondary),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(List<Task> tasks, Color card, Color textPrimary, Color textSecondary) {
    final categories = <String, int>{};
    for (final task in tasks) {
      final cat = task.category?.isNotEmpty == true ? task.category! : 'Uncategorized';
      categories[cat] = (categories[cat] ?? 0) + 1;
    }
    if (categories.isEmpty) return const SizedBox.shrink();
    final total = tasks.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('By Category', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 16),
          ...categories.entries.toList().map((entry) {
            final colors = [AppColors.primary, AppColors.info, AppColors.success, AppColors.warning, AppColors.accent];
            final idx = categories.keys.toList().indexOf(entry.key) % colors.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _progressBar(entry.key, entry.value, total, colors[idx], textSecondary),
            );
          }),
        ],
      ),
    );
  }

  Widget _progressBar(String label, int count, int total, Color color, Color textSecondary) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary)),
            Text('$count (${(pct * 100).toInt()}%)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
