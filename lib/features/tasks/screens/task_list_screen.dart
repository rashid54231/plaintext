import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/user_provider.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Tasks',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Slide 2 Tabs: All | To Do | In Progress | Done
          _buildFilterTabs(isDark, card),
          const SizedBox(height: 10),

          // Slide 2 Search Bar
          _buildSearchBar(card, textPrimary, textSecondary, isDark),
          const SizedBox(height: 12),

          // Task List
          Expanded(
            child: Consumer<TaskProvider>(
              builder: (context, taskProvider, _) {
                List<Task> tasks = isManager ? taskProvider.allTasks : taskProvider.userTasks;
                tasks = _applyFilters(tasks);

                return tasks.isEmpty
                    ? _buildEmptyState(card, textPrimary, textSecondary)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskItem(task, index, card, textPrimary, textSecondary);
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

  // Slide 2: Filter Tabs (All | To Do | In Progress | Done)
  Widget _buildFilterTabs(bool isDark, Color cardColor) {
    final tabs = [
      {'label': 'All', 'value': 'all'},
      {'label': 'To Do', 'value': 'todo'},
      {'label': 'In Progress', 'value': 'in_progress'},
      {'label': 'Done', 'value': 'done'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _filterStatus == tab['value'] || (_filterStatus == 'all' && tab['value'] == 'in_progress');
          return GestureDetector(
            onTap: () => setState(() => _filterStatus = tab['value']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tab['label']!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Slide 2: Search Bar with "In Progress" and clear button
  Widget _buildSearchBar(Color cardColor, Color textPrimary, Color textSecondary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: textSecondary),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(Icons.close_rounded, size: 16, color: textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  List<Task> _applyFilters(List<Task> tasks) {
    List<Task> filtered = tasks;

    switch (_filterStatus) {
      case 'todo':
        filtered = tasks.where((t) => !t.isCompleted && !t.isOverdue).toList();
        break;
      case 'in_progress':
        filtered = tasks.where((t) => !t.isCompleted).toList();
        break;
      case 'done':
        filtered = tasks.where((t) => t.isCompleted).toList();
        break;
      case 'all':
      default:
        filtered = tasks;
        break;
    }

    if (_searchQuery.isNotEmpty && _searchQuery != 'In Progress') {
      filtered = filtered.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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

  Widget _buildEmptyState(Color card, Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'No Tasks Found',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tasks from the backend will appear here',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task, int index, Color card, Color textPrimary, Color textSecondary) {
    final students = context.watch<UserProvider>().students;
    final assignedUsers = students.where((s) => task.assignedUserIds.contains(s.id)).toList();
    final assignedNames = assignedUsers.map((u) => u.name).join(', ');
    final pColor = _getPriorityColor(task.priority);
    final progress = task.isCompleted ? 1.0 : 0.65;

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
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}. ${task.title}',
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
                Icon(Icons.more_horiz_rounded, size: 18, color: textSecondary),
              ],
            ),
            const SizedBox(height: 8),

            // Priority Badges
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.name.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: pColor,
                    ),
                  ),
                ),
                if (task.category != null && task.category!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.category!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Date, Star, Assignee, Progress %
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 13, color: textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormatter.formatShort(task.dueDate),
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: textSecondary),
                ),
                const SizedBox(width: 10),
                Icon(Icons.star_rounded, size: 14, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text(
                  task.priority == Priority.high ? 'High' : 'Normal',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
                ),
                const Spacer(),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    assignedNames.isNotEmpty ? assignedNames[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  assignedNames.isNotEmpty ? assignedNames.split(' ').first : 'All',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Linear Progress Indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(task.isCompleted ? AppColors.success : AppColors.primary),
              ),
            ),
          ],
        ),
      ),
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
