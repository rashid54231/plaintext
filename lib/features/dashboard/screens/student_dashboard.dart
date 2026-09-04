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
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/settings_screen.dart';
import 'calendar_screen.dart';
import 'leaderboard_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
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
    if (up.currentUser != null) {
      await context.read<TaskProvider>().loadUserTasks(up.currentUser!.id!);
      if (mounted) {
        context.read<TaskProvider>().initRealtime(up.currentUser!.id!, false);
      }
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
              _buildHomeTab(user),
              const CalendarScreen(),
              _buildMyTasksTab(),
              const LeaderboardScreen(),
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
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), activeIcon: Icon(Icons.home_rounded, size: 28), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), activeIcon: Icon(Icons.calendar_month_rounded, size: 28), label: 'Calendar'),
                BottomNavigationBarItem(icon: Icon(Icons.task_rounded), activeIcon: Icon(Icons.task_rounded, size: 28), label: 'Tasks'),
                BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), activeIcon: Icon(Icons.emoji_events_rounded, size: 28), label: 'Ranks'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), activeIcon: Icon(Icons.person_rounded, size: 28), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ HOME TAB ============
  Widget _buildHomeTab(User? user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(user, greeting),
              const SizedBox(height: 24),
              _buildProgressSection(),
              const SizedBox(height: 24),
              _buildTodaySection(),
              const SizedBox(height: 24),
              _buildUpcomingSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(User? user, String greeting) {
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
                Text('$greeting,', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Text(user?.name ?? 'Student', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(DateFormatter.formatFull(DateTime.now()),
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final rate = tp.completionRate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Progress", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.02)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Completion Rate', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
                      Text('${(rate * 100).toInt()}%',
                          style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: rate,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _statCard('Total', '${tp.totalTasks}', Icons.assignment_rounded, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Done', '${tp.completedTasks}', Icons.check_circle_rounded, AppColors.success)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statCard('Pending', '${tp.pendingTasks}', Icons.pending_actions_rounded, AppColors.warning)),
              const SizedBox(width: 12),
              Expanded(child: _statCard('Overdue', '${tp.overdueTasks}', Icons.warning_rounded, AppColors.error)),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15), 
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection() {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final today = tp.todayTasks;
        final display = today.isNotEmpty ? today : tp.userTasks.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(today.isNotEmpty ? "Today's Tasks" : 'Recent Tasks',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 14),
            if (tp.isLoading) const ShimmerList(count: 3)
            else if (display.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
                child: Center(child: Column(
                  children: [
                    Icon(Icons.celebration_rounded, size: 40, color: AppColors.success),
                    const SizedBox(height: 10),
                    Text("No tasks for today!", style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _textSecondary)),
                  ],
                )),
              )
            else
              ...display.map((t) => _buildTaskCard(t)),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingSection() {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final upcoming = tp.upcomingTasks;
        if (upcoming.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upcoming Deadlines', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 14),
            ...upcoming.map((t) => _buildUpcomingCard(t)),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: task.isOverdue ? AppColors.error.withValues(alpha: 0.3)
                : task.isCompleted ? AppColors.success.withValues(alpha: 0.3)
                : Colors.transparent),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async => await context.read<TaskProvider>().toggleComplete(task.id!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: task.isCompleted ? AppColors.success : Colors.transparent,
                  border: Border.all(color: task.isCompleted ? AppColors.success : AppColors.border, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: task.isCompleted ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600,
                      color: task.isCompleted ? _textHint : _textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 11, color: _textHint),
                      const SizedBox(width: 4),
                      Text(DateFormatter.formatDueDate(task.dueDate),
                        style: GoogleFonts.plusJakartaSans(fontSize: 11,
                          color: task.isOverdue ? AppColors.error : _textHint,
                          fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.normal)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: task.isCompleted ? AppColors.success.withValues(alpha: 0.1) : _priorityColor(task.priority).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(task.isCompleted ? 'DONE' : task.priority.name.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: task.isCompleted ? AppColors.success : _priorityColor(task.priority))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(Task task) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.schedule_rounded, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
                  const SizedBox(height: 4),
                  Text('Due: ${DateFormatter.formatDateTime(task.dueDate)}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: task.daysUntilDue <= 1 ? AppColors.error.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${task.daysUntilDue}d',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold,
                  color: task.daysUntilDue <= 1 ? AppColors.error : AppColors.warning)),
            ),
          ],
        ),
      ),
    );
  }

  // ============ MY TASKS TAB ============
  Widget _buildMyTasksTab() {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        List<Task> tasks = tp.userTasks;
        if (_searchQuery.isNotEmpty) {
          tasks = tasks.where((t) =>
            t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        }
        if (_filterStatus == 'Pending') {
          tasks = tasks.where((t) => !t.isCompleted && !t.isOverdue).toList();
        } else if (_filterStatus == 'Completed') {
          tasks = tasks.where((t) => t.isCompleted).toList();
        } else if (_filterStatus == 'Overdue') {
          tasks = tasks.where((t) => t.isOverdue).toList();
        }

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Tasks',
                            style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.bold, color: _textPrimary)),
                        const SizedBox(height: 4),
                        Text('You have ${tp.userTasks.where((t) => !t.isCompleted).length} active tasks',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.assignment_rounded, color: AppColors.primary, size: 28),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search your tasks...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: _textHint),
                      prefixIcon: Icon(Icons.search_rounded, color: _textHint, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.cancel_rounded, color: _textHint, size: 20),
                              onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: _statuses.map((s) {
                    final isSelected = _filterStatus == s;
                    IconData icon;
                    switch (s) {
                      case 'All': icon = Icons.dashboard_rounded; break;
                      case 'Pending': icon = Icons.pending_actions_rounded; break;
                      case 'Completed': icon = Icons.task_alt_rounded; break;
                      case 'Overdue': icon = Icons.warning_rounded; break;
                      default: icon = Icons.circle;
                    }
                    return GestureDetector(
                      onTap: () => setState(() => _filterStatus = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected ? AppColors.primaryGradient : null,
                          color: isSelected ? null : _card,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                          border: Border.all(color: isSelected ? Colors.transparent : AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 16, color: isSelected ? Colors.white : _textSecondary),
                            const SizedBox(width: 8),
                            Text(s, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : _textSecondary)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: tp.isLoading
                    ? const ShimmerList()
                    : tasks.isEmpty
                        ? _buildBeautifulEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                            itemCount: tasks.length,
                            itemBuilder: (context, i) => _buildFullTaskCard(tasks[i]),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBeautifulEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
              ),
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
              Icon(
                _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.task_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'No matches found' : 'You\'re all caught up!',
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'We couldn\'t find any tasks matching your search. Try different keywords.'
                  : 'Take a break or check back later for new tasks assigned by your manager.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildFullTaskCard(Task task) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: task.isOverdue ? AppColors.error.withValues(alpha: 0.08)
                  : task.isCompleted ? AppColors.success.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 15, offset: const Offset(0, 8)
            )
          ],
          border: Border.all(
            color: task.isOverdue ? AppColors.error.withValues(alpha: 0.4)
                : task.isCompleted ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.border.withValues(alpha: 0.5),
            width: 1.5
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () async => await context.read<TaskProvider>().toggleComplete(task.id!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      width: 28, height: 28,
                      margin: const EdgeInsets.only(top: 2, right: 14),
                      decoration: BoxDecoration(
                        color: task.isCompleted ? AppColors.success : Colors.transparent,
                        border: Border.all(color: task.isCompleted ? AppColors.success : AppColors.border, width: 2),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: task.isCompleted ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))] : null,
                      ),
                      child: task.isCompleted ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: task.isCompleted ? _textHint : _textPrimary,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                            decorationColor: _textHint,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(task.description,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _textSecondary, height: 1.4),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: task.isCompleted ? AppColors.success.withValues(alpha: 0.1) : _priorityColor(task.priority).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(task.isCompleted ? Icons.check_circle_rounded : Icons.flag_rounded,
                             size: 14, color: task.isCompleted ? AppColors.success : _priorityColor(task.priority)),
                        const SizedBox(width: 4),
                        Text(task.isCompleted ? 'Done' : task.priority.name.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: task.isCompleted ? AppColors.success : _priorityColor(task.priority))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_ind_rounded, size: 14, color: _textHint),
                      const SizedBox(width: 6),
                      Text('Assigned ${DateFormatter.formatShort(task.assignedDate)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: _textHint)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(task.isOverdue ? Icons.warning_rounded : Icons.event_rounded, size: 14, color: task.isOverdue ? AppColors.error : _textHint),
                      const SizedBox(width: 6),
                      Text('Due ${DateFormatter.formatShort(task.dueDate)}',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12,
                            color: task.isOverdue ? AppColors.error : _textHint,
                            fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
              backgroundImage: user?.avatarUrl != null
                  ? CachedNetworkImageProvider(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null
                  ? Text(
                      user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
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
                color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('Student', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
            ),
            const SizedBox(height: 28),
            _profileItem(Icons.email_outlined, 'Email', user?.email ?? ''),
            _profileItem(Icons.phone_outlined, 'Phone', user?.phone?.isNotEmpty == true ? user!.phone! : 'Not set'),
            _profileItem(Icons.calendar_today, 'Joined', DateFormatter.formatFull(user?.createdAt ?? DateTime.now())),
            const SizedBox(height: 20),
            Consumer<TaskProvider>(
              builder: (context, tp, _) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _card, borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Stats', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statChip('${tp.totalTasks}', 'Total', AppColors.primary),
                          _statChip('${tp.completedTasks}', 'Done', AppColors.success),
                          _statChip('${tp.pendingTasks}', 'Pending', AppColors.warning),
                          _statChip('${tp.overdueTasks}', 'Overdue', AppColors.error),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.settings_rounded, color: AppColors.success, size: 20),
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
        color: _card, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.success, size: 20),
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

  Widget _statChip(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _textHint)),
      ],
    );
  }

  Color _priorityColor(Priority p) {
    switch (p) {
      case Priority.high: return AppColors.highPriority;
      case Priority.medium: return AppColors.mediumPriority;
      case Priority.low: return AppColors.lowPriority;
    }
  }
}
//student
//sajbksj
//ghft
//giiftt
//student