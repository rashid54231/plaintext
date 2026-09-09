import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../models/user.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/database_service.dart';
import '../../../shared/widgets/status_badge.dart';
import 'task_detail_screen.dart';
import 'create_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String _filterStatus = 'all';
  String _sortBy = 'dueDate';

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isManager = userProvider.isManager;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.background;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'All Tasks',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterBar(card, textSecondary),
          Expanded(
            child: Consumer<TaskProvider>(
              builder: (context, taskProvider, _) {
                List<Task> tasks = isManager ? taskProvider.allTasks : taskProvider.userTasks;
                tasks = _applyFilters(tasks);

                return tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.task_alt_rounded, size: 48, color: AppColors.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try changing the filter or create a new task',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskItem(task, card, textPrimary, textSecondary);
                        },
                      );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildFilterBar(Color cardColor, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: textSecondary.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', 'pending'),
          const SizedBox(width: 8),
          _buildFilterChip('Completed', 'completed'),
          const SizedBox(width: 8),
          _buildFilterChip('Overdue', 'overdue'),
          const Spacer(),
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: textSecondary),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'dueDate', child: Text('Sort by Due Date')),
              const PopupMenuItem(value: 'priority', child: Text('Sort by Priority')),
              const PopupMenuItem(value: 'status', child: Text('Sort by Status')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }

  List<Task> _applyFilters(List<Task> tasks) {
    List<Task> filtered = tasks;

    switch (_filterStatus) {
      case 'pending':
        filtered = tasks.where((t) => !t.isCompleted && !t.isOverdue).toList();
        break;
      case 'completed':
        filtered = tasks.where((t) => t.isCompleted).toList();
        break;
      case 'overdue':
        filtered = tasks.where((t) => t.isOverdue).toList();
        break;
    }

    switch (_sortBy) {
      case 'dueDate':
        filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case 'priority':
        filtered.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        break;
      case 'status':
        filtered.sort((a, b) => a.isCompleted.toString().compareTo(b.isCompleted.toString()));
        break;
    }

    return filtered;
  }

  Widget _buildTaskItem(Task task, Color card, Color textPrimary, Color textSecondary) {
    return FutureBuilder<List<User>>(
      future: DatabaseService.instance.getTaskAssignedUsers(task.id!),
      builder: (context, snapshot) {
        final assignedUsers = snapshot.data ?? [];
        final assignedNames = assignedUsers.map((u) => u.name).join(', ');

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: task.isOverdue
                    ? AppColors.error.withValues(alpha: 0.35)
                    : task.isCompleted
                        ? AppColors.success.withValues(alpha: 0.3)
                        : textSecondary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task.priority).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.priority.name.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(task.priority),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge.fromStatus(task.status),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        assignedUsers.isEmpty ? 'No students' : 'To: $assignedNames',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_rounded, size: 14, color: textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      DateFormatter.formatDueDate(task.dueDate),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: task.isOverdue ? AppColors.error : textSecondary,
                        fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return AppColors.highPriority;
      case Priority.medium:
        return AppColors.mediumPriority;
      case Priority.low:
        return AppColors.lowPriority;
    }
  }
}
