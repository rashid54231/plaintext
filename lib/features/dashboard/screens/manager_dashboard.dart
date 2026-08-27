import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../models/user.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/database_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../tasks/screens/create_task_screen.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/settings_screen.dart';
import 'analytics_screen.dart';
import 'calendar_screen.dart';
import 'leaderboard_screen.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  int _currentIndex = 0;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'All';
  static const _statuses = ['All', 'Pending', 'Completed', 'Overdue'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final up = context.read<UserProvider>();
    await up.loadStudents();
    if (up.currentUser != null) {
      final taskProvider = context.read<TaskProvider>();
      await Future.wait([
        taskProvider.loadAllTasks(),
        taskProvider.loadAssignedTasks(up.currentUser!.id!),
      ]);
      taskProvider.initRealtime(up.currentUser!.id!, true);
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? AppColors.backgroundDark : AppColors.background;
  Color get _card => _isDark ? AppColors.cardDark : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get _textHint => _isDark ? AppColors.textHintDark : AppColors.textHint;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -150,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: const SizedBox(),
            ),
          ),
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildOverviewTab(user),
              _buildStudentsTab(),
              _buildTasksTab(),
              const AnalyticsScreen(),
              _buildProfileTab(user),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
        decoration: BoxDecoration(
          color: _isDark ? _card.withValues(alpha: 0.8) : _card.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: _textHint,
              showSelectedLabels: true,
              showUnselectedLabels: false,
              selectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 10),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), activeIcon: Icon(Icons.dashboard_rounded, size: 28), label: 'Overview'),
                BottomNavigationBarItem(icon: Icon(Icons.people_rounded), activeIcon: Icon(Icons.people_rounded, size: 28), label: 'Students'),
                BottomNavigationBarItem(icon: Icon(Icons.task_rounded), activeIcon: Icon(Icons.task_rounded, size: 28), label: 'Tasks'),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), activeIcon: Icon(Icons.bar_chart_rounded, size: 28), label: 'Analytics'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), activeIcon: Icon(Icons.person_rounded, size: 28), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateTaskScreen())),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('New Task', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  // ============ OVERVIEW TAB ============
  Widget _buildOverviewTab(User? user) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(user),
              const SizedBox(height: 16),
              _buildActionButtons(context),
              const SizedBox(height: 24),
              _buildStatsGrid(),
              const SizedBox(height: 24),
              _buildRecentTasks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text('Calendar', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight.withOpacity(0.2),
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
            icon: const Icon(Icons.emoji_events_rounded, size: 18),
            label: Text('Leaderboard', style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700).withOpacity(0.2),
              foregroundColor: const Color(0xFFDAA520),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader(User? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Text(user?.name ?? 'Manager', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(DateFormatter.formatFull(DateTime.now()),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final all = tp.allTasks;
        final total = all.length;
        final completed = all.where((t) => t.isCompleted).length;
        final pending = all.where((t) => !t.isCompleted && !t.isOverdue).length;
        final overdue = all.where((t) => t.isOverdue).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _statCard('Total', '$total', Icons.assignment_rounded, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Completed', '$completed', Icons.check_circle_rounded, AppColors.success)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statCard('Pending', '$pending', Icons.pending_actions_rounded, AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Overdue', '$overdue', Icons.warning_rounded, AppColors.error)),
            ]),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 8))],
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 14),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRecentTasks() {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final recent = tp.allTasks.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Tasks', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: Text('View All', style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (tp.isLoading)
              const ShimmerList(count: 3)
            else if (recent.isEmpty)
              EmptyState(
                icon: Icons.task_rounded, title: 'No tasks yet',
                subtitle: 'Create your first task',
                buttonText: 'Create Task',
                onButtonPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateTaskScreen())),
              )
            else
              ...recent.map((t) => _buildTaskItem(t)),
          ],
        );
      },
    );
  }

  Widget _buildTaskItem(Task task) {
    return FutureBuilder<List<User>>(
      future: DatabaseService.instance.getTaskAssignedUsers(task.id!),
      builder: (context, snap) {
        final names = (snap.data ?? []).map((u) => u.name).join(', ');
        return GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: task.isOverdue ? AppColors.error.withValues(alpha: 0.3) : Colors.transparent),
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _priorityColor(task.priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_priorityIcon(task.priority), color: _priorityColor(task.priority), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14, color: _textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(snap.data == null ? 'Loading...' : (snap.data!.isEmpty ? 'No students' : 'To: $names'),
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(
                      text: task.isCompleted ? 'Done' : (task.isOverdue ? 'Overdue' : 'Active'),
                      backgroundColor: (task.isCompleted ? AppColors.success : task.isOverdue ? AppColors.error : AppColors.info).withValues(alpha: 0.1),
                      textColor: task.isCompleted ? AppColors.success : task.isOverdue ? AppColors.error : AppColors.info,
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormatter.formatShort(task.dueDate),
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _textHint)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============ STUDENTS TAB ============
  Widget _buildStudentsTab() {
    return Consumer<UserProvider>(
      builder: (context, up, _) {
        final students = up.students;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text('Students (${students.length})',
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
              ),
              Expanded(
                child: students.isEmpty
                    ? EmptyState(icon: Icons.people_rounded, title: 'No students yet',
                        subtitle: 'Students will appear here when they sign up')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: students.length,
                        itemBuilder: (context, index) => _buildStudentCard(students[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentCard(User student) {
    return FutureBuilder<Map<String, int>>(
      future: DatabaseService.instance.getTaskCountByUser(student.id!),
      builder: (context, snap) {
        final stats = snap.data ?? {'total': 0, 'completed': 0, 'pending': 0, 'overdue': 0};
        final total = stats['total'] ?? 0;
        final completed = stats['completed'] ?? 0;
        final pct = total > 0 ? completed / total : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: student.avatarUrl != null
                        ? CachedNetworkImageProvider(student.avatarUrl!)
                        : null,
                    child: student.avatarUrl == null
                        ? Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: _textPrimary)),
                        Text(student.email, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$completed/$total',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: _textHint, size: 20),
                    onSelected: (value) async {
                      if (value == 'promote') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Promote to Manager'),
                            content: Text('Are you sure you want to make ${student.name} a Manager?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Promote', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          final success = await context.read<UserProvider>().promoteToManager(student);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${student.name} is now a Manager!'), backgroundColor: AppColors.success)
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'promote',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('Make Manager'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniStat('Total', '${stats['total']}', AppColors.primary),
                  _miniStat('Done', '${stats['completed']}', AppColors.success),
                  _miniStat('Pending', '${stats['pending']}', AppColors.warning),
                  _miniStat('Overdue', '${stats['overdue']}', AppColors.error),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: _textHint)),
      ],
    );
  }

  // ============ TASKS TAB ============
  Widget _buildTasksTab() {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        List<Task> tasks = tp.allTasks;

        // Search filter
        if (_searchQuery.isNotEmpty) {
          tasks = tasks.where((t) =>
            t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        }

        // Status filter
        if (_filterStatus == 'Pending') tasks = tasks.where((t) => !t.isCompleted && !t.isOverdue).toList();
        else if (_filterStatus == 'Completed') tasks = tasks.where((t) => t.isCompleted).toList();
        else if (_filterStatus == 'Overdue') tasks = tasks.where((t) => t.isOverdue).toList();

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('All Tasks (${tp.allTasks.length})',
                            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _textHint),
                        prefixIcon: Icon(Icons.search, color: _textHint, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: _textHint, size: 18),
                                onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                            : null,
                        filled: true,
                        fillColor: _card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statuses.map((s) {
                          final isSelected = _filterStatus == s;
                          return GestureDetector(
                            onTap: () => setState(() => _filterStatus = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : _card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                              ),
                              child: Text(s, style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white : _textSecondary)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tp.isLoading
                    ? const ShimmerList()
                    : tasks.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: _searchQuery.isNotEmpty ? 'No results found' : 'No tasks yet',
                            subtitle: _searchQuery.isNotEmpty ? 'Try a different search' : 'Tap + to create a task',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                            itemCount: tasks.length,
                            itemBuilder: (context, i) => _buildAllTaskItem(tasks[i]),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllTaskItem(Task task) {
    return FutureBuilder<List<User>>(
      future: DatabaseService.instance.getTaskAssignedUsers(task.id!),
      builder: (context, snap) {
        final names = (snap.data ?? []).map((u) => u.name).join(', ');
        return Dismissible(
          key: Key('task_${task.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          confirmDismiss: (_) async => await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Task'),
              content: const Text('Are you sure?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete', style: TextStyle(color: AppColors.error))),
              ],
            ),
          ),
          onDismissed: (_) => context.read<TaskProvider>().deleteTask(task.id!),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: task.isOverdue ? AppColors.error.withValues(alpha: 0.3)
                      : task.isCompleted ? AppColors.success.withValues(alpha: 0.3)
                      : Colors.transparent),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _priorityColor(task.priority).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(task.priority.name.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold,
                                color: _priorityColor(task.priority))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(task.title,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (task.isCompleted) ...[
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      ] else if (task.isOverdue) ...[
                        const Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
                      ],
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(task.description,
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _textSecondary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 13, color: _textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(snap.data == null ? '' : (snap.data!.isEmpty ? 'No students' : 'To: $names'),
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSecondary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Icon(Icons.calendar_today, size: 13, color: _textHint),
                      const SizedBox(width: 4),
                      Text(DateFormatter.formatDueDate(task.dueDate),
                          style: GoogleFonts.plusJakartaSans(fontSize: 12,
                              color: task.isOverdue ? AppColors.error : _textSecondary,
                              fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============ PROFILE TAB ============
  Widget _buildProfileTab(User? user) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: user?.avatarUrl != null
                  ? CachedNetworkImageProvider(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null
                  ? Text(
                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(user?.name ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Manager', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
            const SizedBox(height: 28),
            _profileItem(Icons.email_outlined, 'Email', user?.email ?? ''),
            _profileItem(Icons.phone_outlined, 'Phone', user?.phone?.isNotEmpty == true ? user!.phone! : 'Not set'),
            _profileItem(Icons.calendar_today, 'Joined', DateFormatter.formatFull(user?.createdAt ?? DateTime.now())),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 20),
                    ),
                    title: Text('Settings', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, color: _textPrimary)),
                    trailing: Icon(Icons.chevron_right_rounded, color: _textHint),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                  const Divider(height: 1, indent: 60, endIndent: 16),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                    ),
                    title: Text('Logout', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, color: AppColors.error)),
                    onTap: () {
                      context.read<UserProvider>().logout();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _profileItem(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _textHint)),
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  // ============ HELPERS ============
  Color _priorityColor(Priority p) {
    switch (p) {
      case Priority.high: return AppColors.highPriority;
      case Priority.medium: return AppColors.mediumPriority;
      case Priority.low: return AppColors.lowPriority;
    }
  }

  IconData _priorityIcon(Priority p) {
    switch (p) {
      case Priority.high: return Icons.priority_high_rounded;
      case Priority.medium: return Icons.remove_rounded;
      case Priority.low: return Icons.keyboard_arrow_down_rounded;
    }
  }
}
//manager