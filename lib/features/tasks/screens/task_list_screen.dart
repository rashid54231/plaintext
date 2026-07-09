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

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
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
                            Icon(Icons.task_rounded, size: 64, color: AppColors.textHint),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks found',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: AppColors.textSecondary,
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
                          return _buildTaskItem(task);
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
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
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
            icon: const Icon(Icons.sort_rounded, color: AppColors.textSecondary),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.divider,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
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

  Widget _buildTaskItem(Task task) {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: task.isOverdue
                    ? AppColors.error.withOpacity(0.3)
                    : task.isCompleted
                        ? AppColors.success.withOpacity(0.3)
                        : Colors.transparent,
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
                        color: _getPriorityColor(task.priority).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.priority.name.toUpperCase(),
                        style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (task.isCompleted)
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                    else if (task.isOverdue)
                      const Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      assignedUsers.isEmpty ? 'No students' : 'To: $assignedNames',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.calendar_today, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      DateFormatter.formatDueDate(task.dueDate),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: task.isOverdue ? AppColors.error : AppColors.textSecondary,
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
