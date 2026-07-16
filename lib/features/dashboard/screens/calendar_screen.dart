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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text('Calendar',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: TableCalendar<Task>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: (day) => _getEventsForDay(day, tasks),
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.5), shape: BoxShape.circle),
                      selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      markerDecoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      defaultTextStyle: GoogleFonts.inter(color: _textPrimary),
                      weekendTextStyle: GoogleFonts.inter(color: AppColors.error),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
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
                ).animate().fade().slideY(begin: 0.2, end: 0),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Tasks on ${DateFormatter.formatShort(_selectedDay ?? _focusedDay)}',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: selectedTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textHint.withValues(alpha: 0.5)),
                              const SizedBox(height: 16),
                              Text('No tasks for this day', style: GoogleFonts.inter(color: _textSecondary)),
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
                                    color: task.isOverdue ? AppColors.error.withValues(alpha: 0.3) : Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(task.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: _textPrimary)),
                                          if (task.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(task.description, style: GoogleFonts.inter(fontSize: 12, color: _textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ]
                                        ],
                                      ),
                                    ),
                                    StatusBadge(
                                      text: task.isCompleted ? 'Done' : (task.isOverdue ? 'Overdue' : 'Active'),
                                      backgroundColor: (task.isCompleted ? AppColors.success : task.isOverdue ? AppColors.error : AppColors.info).withValues(alpha: 0.1),
                                      textColor: task.isCompleted ? AppColors.success : task.isOverdue ? AppColors.error : AppColors.info,
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fade().slideX(begin: 0.2, end: 0, delay: Duration(milliseconds: 50 * index));
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
