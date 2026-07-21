import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
      context.read<TaskProvider>().initRealtime(up.currentUser!.id!, false);
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(user),
          const CalendarScreen(),
          _buildMyTasksTab(),
          const LeaderboardScreen(),
          _buildProfileTab(user),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _card,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
            BottomNavigationBarItem(icon: Icon(Icons.task_rounded), label: 'Tasks'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Ranks'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
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
          padding: const EdgeInsets.all(20),
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
                Text('$greeting,', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Text(user?.name ?? 'Student', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text(DateFormatter.formatFull(DateTime.now()),
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
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
            Text("Today's Progress", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Completion Rate', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _textSecondary)),
                      Text('${(rate * 100).toInt()}%',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: rate,
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 10,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textSecondary)),
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
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
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
                    Text("No tasks for today!", style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
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
            Text('Upcoming Deadlines', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary)),
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
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                      color: task.isCompleted ? _textHint : _textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 11, color: _textHint),
                      const SizedBox(width: 4),
                      Text(DateFormatter.formatDueDate(task.dueDate),
                        style: GoogleFonts.inter(fontSize: 11,
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
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: task.isCompleted ? AppColors.success : _priorityColor(task.priority))),
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
                  Text(task.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
                  const SizedBox(height: 4),
                  Text('Due: ${DateFormatter.formatDateTime(task.dueDate)}',
                      style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
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
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold,
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
                        Text('My Tasks (${tp.userTasks.length})',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.inter(fontSize: 14, color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: GoogleFonts.inter(color: _textHint),
                        prefixIcon: Icon(Icons.search, color: _textHint, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: _textHint, size: 18),
                                onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                            : null,
                        filled: true,
                        fillColor: _card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                              child: Text(s, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500,
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
                            icon: _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.task_rounded,
                            title: _searchQuery.isNotEmpty ? 'No results found' : 'No tasks yet',
                            subtitle: _searchQuery.isNotEmpty
                                ? 'Try a different search term'
                                : 'Tasks assigned by your manager will appear here',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _buildFullTaskCard(Task task) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
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
                    color: task.isCompleted ? AppColors.success.withValues(alpha: 0.1) : _priorityColor(task.priority).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(task.isCompleted ? 'DONE' : task.priority.name.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: task.isCompleted ? AppColors.success : _priorityColor(task.priority))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(task.title,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                      color: task.isCompleted ? _textHint : _textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (task.isCompleted) ...[
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                ] else if (task.isOverdue) ...[
                  const Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
                ] else ...[
                  Icon(Icons.circle_outlined, color: AppColors.border, size: 20),
                ],
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(task.description,
                  style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: _textHint),
                const SizedBox(width: 4),
                Text('Assigned: ${DateFormatter.formatShort(task.assignedDate)}',
                    style: GoogleFonts.inter(fontSize: 11, color: _textHint)),
                const Spacer(),
                Icon(Icons.event_rounded, size: 12, color: _textHint),
                const SizedBox(width: 4),
                Text('Due: ${DateFormatter.formatShort(task.dueDate)}',
                    style: GoogleFonts.inter(fontSize: 11,
                      color: task.isOverdue ? AppColors.error : _textHint,
                      fontWeight: task.isOverdue ? FontWeight.w600 : FontWeight.normal)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============ PROFILE TAB ============
  Widget _buildProfileTab(User? user) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 100, height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(
                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white),
              )),
            ),
            const SizedBox(height: 16),
            Text(user?.name ?? '', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('Student', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
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
                      Text('My Stats', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: _textPrimary)),
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
                    title: Text('Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: _textPrimary)),
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
                    title: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AppColors.error)),
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
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textHint)),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: _textHint)),
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
