import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/database_service.dart';
import '../../tasks/screens/task_detail_screen.dart';

enum NotificationFilter { all, unread, tasks, grades, reminders }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final String category; // 'tasks', 'grades', 'reminders'
  final Task? task;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.category,
    this.task,
    this.isRead = false,
  });
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  NotificationFilter _selectedFilter = NotificationFilter.all;
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  Set<String> _readIds = {};
  Set<String> _dismissedIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final readList = prefs.getStringList('read_notification_ids') ?? [];
    final dismissedList = prefs.getStringList('dismissed_notification_ids') ?? [];
    _readIds = readList.toSet();
    _dismissedIds = dismissedList.toSet();
  }

  Future<void> _saveReadState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_notification_ids', _readIds.toList());
  }

  Future<void> _saveDismissedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissed_notification_ids', _dismissedIds.toList());
  }

  Future<void> _loadNotifications() async {
    await _loadPreferences();
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    final taskProvider = context.read<TaskProvider>();
    final currentUser = userProvider.currentUser;
    final isManager = userProvider.isManager;

    final List<NotificationItem> items = [];

    try {
      final tasks = isManager ? taskProvider.allTasks : taskProvider.userTasks;

      for (final task in tasks) {
        if (task.id == null) continue;

        // 1. Task Overdue Reminder
        if (task.isOverdue && !task.isCompleted) {
          final id = 'overdue_${task.id}';
          if (!_dismissedIds.contains(id)) {
            items.add(NotificationItem(
              id: id,
              title: 'Task Overdue!',
              body: '"${task.title}" was due on ${DateFormatter.formatDateTime(task.dueDate)}.',
              timestamp: task.dueDate,
              icon: Icons.error_outline_rounded,
              color: AppColors.error,
              category: 'reminders',
              task: task,
              isRead: _readIds.contains(id),
            ));
          }
        }
        // 2. Due Soon Reminder (within 24 hours)
        else if (!task.isCompleted &&
            task.daysUntilDue <= 1 &&
            task.daysUntilDue >= 0) {
          final id = 'due_soon_${task.id}';
          if (!_dismissedIds.contains(id)) {
            items.add(NotificationItem(
              id: id,
              title: 'Deadline Approaching',
              body: '"${task.title}" is due soon (${DateFormatter.formatDateTime(task.dueDate)}).',
              timestamp: task.dueDate.subtract(const Duration(hours: 12)),
              icon: Icons.access_time_rounded,
              color: AppColors.warning,
              category: 'reminders',
              task: task,
              isRead: _readIds.contains(id),
            ));
          }
        }

        // 3. New Task Assigned Notification
        final assignId = 'assigned_${task.id}';
        if (!_dismissedIds.contains(assignId)) {
          items.add(NotificationItem(
            id: assignId,
            title: isManager ? 'Task Created' : 'New Task Assigned',
            body: isManager
                ? 'You assigned "${task.title}" with priority ${task.priority.name.toUpperCase()}.'
                : 'You have been assigned: "${task.title}". Priority: ${task.priority.name.toUpperCase()}.',
            timestamp: task.assignedDate,
            icon: Icons.assignment_rounded,
            color: AppColors.primary,
            category: 'tasks',
            task: task,
            isRead: _readIds.contains(assignId),
          ));
        }

        // 4. Role specific checks
        if (isManager) {
          // Check submissions from students
          try {
            final assignments = await DatabaseService.instance.getTaskAssignments(task.id!);
            for (final a in assignments) {
              if (a.isCompleted || a.status == 'submitted') {
                final subId = 'submission_${task.id}_${a.userId}';
                if (!_dismissedIds.contains(subId)) {
                  items.add(NotificationItem(
                    id: subId,
                    title: 'New Student Submission',
                    body: '${a.userName ?? 'A student'} submitted work for "${task.title}".',
                    timestamp: a.submittedAt ?? task.assignedDate,
                    icon: Icons.file_present_rounded,
                    color: AppColors.secondary,
                    category: 'tasks',
                    task: task,
                    isRead: _readIds.contains(subId),
                  ));
                }
              }
            }
          } catch (_) {}
        } else if (currentUser != null) {
          // Check if student's assignment has been graded
          try {
            final myAssign = await DatabaseService.instance.getStudentAssignment(task.id!, currentUser.id!);
            if (myAssign != null && myAssign.marks != null) {
              final gradeId = 'grade_${task.id}';
              if (!_dismissedIds.contains(gradeId)) {
                items.add(NotificationItem(
                  id: gradeId,
                  title: 'Grade & Feedback Received! 🌟',
                  body: 'Score: ${myAssign.marks}${task.maxMarks != null ? '/${task.maxMarks}' : ''} for "${task.title}".',
                  timestamp: myAssign.reviewedAt ?? task.dueDate,
                  icon: Icons.verified_rounded,
                  color: AppColors.success,
                  category: 'grades',
                  task: task,
                  isRead: _readIds.contains(gradeId),
                ));
              }
            }
          } catch (_) {}
        }
      }

      // Sort notifications by timestamp descending (newest first)
      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
        _readIds.add(n.id);
      }
    });
    _saveReadState();
  }

  void _markAsRead(NotificationItem item) {
    if (!item.isRead) {
      setState(() {
        item.isRead = true;
        _readIds.add(item.id);
      });
      _saveReadState();
    }
  }

  void _dismissNotification(NotificationItem item) {
    setState(() {
      _notifications.removeWhere((n) => n.id == item.id);
      _dismissedIds.add(item.id);
    });
    _saveDismissedState();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification dismissed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _dismissedIds.remove(item.id);
              _notifications.insert(0, item);
            });
            _saveDismissedState();
          },
        ),
      ),
    );
  }

  void _clearAllNotifications() {
    setState(() {
      for (final n in _notifications) {
        _dismissedIds.add(n.id);
      }
      _notifications.clear();
    });
    _saveDismissedState();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  List<NotificationItem> get _filteredNotifications {
    switch (_selectedFilter) {
      case NotificationFilter.all:
        return _notifications;
      case NotificationFilter.unread:
        return _notifications.where((n) => !n.isRead).toList();
      case NotificationFilter.tasks:
        return _notifications.where((n) => n.category == 'tasks').toList();
      case NotificationFilter.grades:
        return _notifications.where((n) => n.category == 'grades').toList();
      case NotificationFilter.reminders:
        return _notifications.where((n) => n.category == 'reminders').toList();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Notifications',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount new',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: textPrimary),
              onSelected: (val) {
                if (val == 'read_all') _markAllAsRead();
                if (val == 'clear_all') _clearAllNotifications();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Mark all as read'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded, size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(card, textPrimary, textSecondary),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredNotifications.isEmpty
                    ? _buildEmptyState(textPrimary, textSecondary)
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          itemCount: _filteredNotifications.length,
                          itemBuilder: (ctx, i) {
                            final item = _filteredNotifications[i];
                            return _buildNotificationCard(item, card, textPrimary, textSecondary);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(Color card, Color textPrimary, Color textSecondary) {
    final filters = [
      {'label': 'All', 'filter': NotificationFilter.all},
      {'label': 'Unread', 'filter': NotificationFilter.unread},
      {'label': 'Tasks', 'filter': NotificationFilter.tasks},
      {'label': 'Grades', 'filter': NotificationFilter.grades},
      {'label': 'Reminders', 'filter': NotificationFilter.reminders},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final filter = f['filter'] as NotificationFilter;
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                f['label'] as String,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
              onSelected: (val) => setState(() => _selectedFilter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotificationCard(
    NotificationItem item,
    Color card,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _dismissNotification(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _markAsRead(item);
          if (item.task != null) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TaskDetailScreen(task: item.task!)),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !item.isRead
                  ? item.color.withValues(alpha: 0.4)
                  : AppColors.border.withValues(alpha: 0.4),
              width: !item.isRead ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: !item.isRead ? 0.08 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Circle
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 12),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: !item.isRead ? FontWeight.w800 : FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormatter.formatDateTime(item.timestamp),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                        if (item.task != null)
                          Text(
                            'View Task →',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            'All Caught Up!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No notifications at the moment.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
