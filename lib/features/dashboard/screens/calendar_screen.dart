import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../../shared/widgets/status_badge.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<Task> _getEventsForDay(DateTime day, List<Task> tasks) {
    return tasks.where((t) {
      final isDueOnDay = t.dueDate.year == day.year &&
          t.dueDate.month == day.month &&
          t.dueDate.day == day.day;
      final isAssignedOnDay = t.assignedDate.year == day.year &&
          t.assignedDate.month == day.month &&
          t.assignedDate.day == day.day;
      return isDueOnDay || isAssignedOnDay;
    }).toList();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? AppColors.backgroundDark : AppColors.background;
  Color get _card => _isDark ? AppColors.cardDark : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final tasks = tp.allTasks;
        final selectedTasks = _getEventsForDay(_selectedDay ?? _focusedDay, tasks);

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _textSecondary.withValues(alpha: 0.15)),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Task Calendar',
                              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary)),
                          Text('Track deadlines & schedules',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _textSecondary.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: _isDark ? 0.3 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TableCalendar<Task>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: (day) => _getEventsForDay(day, tasks),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        gradient: AppColors.heroGradient,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      defaultTextStyle: GoogleFonts.plusJakartaSans(color: _textPrimary, fontWeight: FontWeight.w500),
                      weekendTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.error, fontWeight: FontWeight.w500),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
                      leftChevronIcon: Icon(Icons.chevron_left, color: _textPrimary),
                      rightChevronIcon: Icon(Icons.chevron_right, color: _textPrimary),
                    ),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                  ),
                ).animate().fade().slideY(begin: 0.1, end: 0),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Tasks on ${DateFormatter.formatShort(_selectedDay ?? _focusedDay)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
                      const Spacer(),
                      Text('${selectedTasks.length} task${selectedTasks.length == 1 ? '' : 's'}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: selectedTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.event_available_rounded, size: 40, color: AppColors.primary.withValues(alpha: 0.7)),
                              ),
                              const SizedBox(height: 16),
                              Text('No tasks for this day',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: _textPrimary)),
                              const SizedBox(height: 4),
                              Text('Enjoy your free time!',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSecondary)),
                            ],
                          ).animate().fade(),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: selectedTasks.length,
                          itemBuilder: (context, index) {
                            final task = selectedTasks[index];
                            return GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: task.isOverdue
                                        ? AppColors.error.withValues(alpha: 0.3)
                                        : _textSecondary.withValues(alpha: 0.1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: _textPrimary,
                                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                          if (task.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              task.description,
                                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge.fromStatus(task.status),
                                  ],
                                ),
                              ),
                            ).animate().fade().slideX(begin: 0.1, end: 0, delay: Duration(milliseconds: 40 * index));
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
