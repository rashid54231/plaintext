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
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../tasks/screens/task_detail_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/screens/settings_screen.dart';
import 'calendar_screen.dart';
import 'leaderboard_screen.dart';
import '../../notifications/screens/notification_center_screen.dart';

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
          // Ambient Mesh Glowing Orbs
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: _isDark ? 0.25 : 0.14),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 240,
            left: -100,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF06B6D4).withValues(alpha: _isDark ? 0.2 : 0.12),
                    const Color(0xFF06B6D4).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: _isDark ? 0.18 : 0.1),
                    AppColors.secondary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
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
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  // ============ MODERN FLOATING GLASS DOCK ============
  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.only(left: 18, right: 18, bottom: 22),
      decoration: BoxDecoration(
        color: _isDark
            ? const Color(0xFF131B2E).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: _isDark ? 0.2 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: _isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.border.withValues(alpha: 0.9),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.grid_view_rounded, 'Home'),
                _buildNavItem(1, Icons.calendar_month_rounded, 'Calendar'),
                _buildNavItem(2, Icons.task_alt_rounded, 'Tasks'),
                _buildNavItem(3, Icons.military_tech_rounded, 'Ranks'),
                _buildNavItem(4, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: _isDark ? 0.25 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isSelected ? 22 : 21,
              color: isSelected ? AppColors.primary : _textHint,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============ HOME TAB ============
  Widget _buildHomeTab(User? user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(user, greeting),
              const SizedBox(height: 20),
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
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final hasAlerts = tp.overdueTasks > 0;
        final alertCount = tp.overdueTasks;

        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Luxury Avatar with Multi-stop Gradient Border & Glow
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF6366F1),
                            Color(0xFF8B5CF6),
                            Color(0xFFEC4899),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: ClipOval(
                        child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    Container(color: const Color(0xFF1E293B)),
                                errorWidget: (context, url, error) =>
                                    _buildHeaderInitial(user),
                              )
                            : _buildHeaderInitial(user),
                      ),
                    ),
                    // Active Status Dot
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981),
                          border: Border.all(
                            color: _isDark ? const Color(0xFF0F172A) : Colors.white,
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // User Info Hierarchy
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'STUDENT WORKSPACE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.name ?? 'Alex Johnson',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$greeting • Keep pushing forward!',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sleek Frosted Notification Button
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen(),
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _isDark
                              ? const Color(0xFF1E2638)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : AppColors.border.withValues(alpha: 0.9),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.notifications_outlined,
                          color: _isDark ? Colors.white : const Color(0xFF0F172A),
                          size: 22,
                        ),
                      ),
                      // Vibrant Notification Badge
                      if (hasAlerts || tp.pendingTasks > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasAlerts ? AppColors.error : AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isDark ? const Color(0xFF0F172A) : Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (hasAlerts ? AppColors.error : AppColors.primary)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${hasAlerts ? alertCount : tp.pendingTasks}',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // High Priority Alert Banner (if overdue tasks exist)
            if (hasAlerts)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationCenterScreen(),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.error.withValues(alpha: _isDark ? 0.22 : 0.08),
                        AppColors.warning.withValues(alpha: _isDark ? 0.15 : 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: _isDark ? 0.4 : 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Action Required',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                            Text(
                              '$alertCount overdue task(s) require your immediate attention.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderInitial(User? user) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'A',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final total = tp.totalTasks;
        final completed = tp.completedTasks;
        final overdue = tp.overdueTasks;

        final focusRate = total > 0 ? ((total - overdue) / total).clamp(0.0, 1.0) : 1.0;
        final goalRate = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
        final taskRate = tp.completionRate.clamp(0.0, 1.0);

        final focusPct = (focusRate * 100).toInt();
        final goalPct = (goalRate * 100).toInt();
        final taskPct = (taskRate * 100).toInt();

        final todayCompleted = tp.todayTasks.isNotEmpty
            ? tp.todayTasks.where((t) => t.isCompleted).length
            : completed;
        final todayTotal = tp.todayTasks.isNotEmpty ? tp.todayTasks.length : total;
        final streakDays = _calculateStreak(tp.userTasks);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ MAIN PRODUCTIVITY OVERVIEW CARD ============
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isDark
                      ? [const Color(0xFF1A2338), const Color(0xFF111827)]
                      : [Colors.white, const Color(0xFFF9FAFC)],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.12),
                  width: 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: _isDark ? 0.18 : 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Productivity Overview',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Real-time task performance',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (taskRate >= 0.7
                                  ? AppColors.success
                                  : (taskRate >= 0.3
                                      ? AppColors.primary
                                      : const Color(0xFFF59E0B)))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (taskRate >= 0.7
                                    ? AppColors.success
                                    : (taskRate >= 0.3
                                        ? AppColors.primary
                                        : const Color(0xFFF59E0B)))
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: taskRate >= 0.7
                                    ? AppColors.success
                                    : (taskRate >= 0.3
                                        ? AppColors.primary
                                        : const Color(0xFFF59E0B)),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              taskRate >= 0.7
                                  ? 'Optimal'
                                  : (taskRate >= 0.3 ? 'On Track' : 'Starting'),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: taskRate >= 0.7
                                    ? AppColors.success
                                    : (taskRate >= 0.3
                                        ? AppColors.primary
                                        : const Color(0xFFF59E0B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // 3 High-End Circular Indicator Rings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCircularRing(
                        '$focusPct%',
                        'Focus',
                        focusRate,
                        const Color(0xFF0284C7),
                        Icons.center_focus_strong_rounded,
                      ),
                      _buildCircularRing(
                        '$goalPct%',
                        'Goal',
                        goalRate,
                        const Color(0xFF6366F1),
                        Icons.track_changes_rounded,
                      ),
                      _buildCircularRing(
                        '$taskPct%',
                        'Tasks',
                        taskRate,
                        const Color(0xFF10B981),
                        Icons.check_circle_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Integrated Bottom Progress Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF1F5F9).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.border.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Overall Completion Rate',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _textSecondary,
                              ),
                            ),
                            Text(
                              '$taskPct%',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: taskRate.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: _isDark ? 0.2 : 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ============ TWO SPLIT BENTO CARDS: TODAY'S TASKS & STREAK ============
            Row(
              children: [
                // Today's Tasks Bento Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isDark
                            ? [
                                const Color(0xFF1E2638),
                                const Color(0xFF141C2E),
                              ]
                            : [
                                const Color(0xFFEEF2FF),
                                Colors.white,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: _isDark ? 0.25 : 0.18),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              "Today's Goal",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _textSecondary,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: _textHint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$todayCompleted',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              ' / $todayTotal',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _textHint,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                todayTotal > 0
                                    ? '${((todayCompleted / todayTotal) * 100).toInt()}%'
                                    : '0%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: todayTotal > 0 ? (todayCompleted / todayTotal) : 0.0,
                            minHeight: 5,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Streak Bento Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isDark
                            ? [
                                const Color(0xFF261D15),
                                const Color(0xFF1A1410),
                              ]
                            : [
                                const Color(0xFFFFF7ED),
                                Colors.white,
                              ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: _isDark ? 0.35 : 0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                size: 16,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            Text(
                              'Daily Streak',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _textSecondary,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: _textHint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$streakDays',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              ' Days',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _textHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                streakDays > 0 ? '🔥 On Track' : '⚡ Complete 1 task',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ============ QUICK STATUS STAT BENTO GRID (2x2) ============
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Assigned',
                    '${tp.totalTasks}',
                    Icons.assignment_rounded,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Completed',
                    '${tp.completedTasks}',
                    Icons.check_circle_rounded,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Pending',
                    '${tp.pendingTasks}',
                    Icons.pending_actions_rounded,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Overdue',
                    '${tp.overdueTasks}',
                    Icons.warning_amber_rounded,
                    AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  int _calculateStreak(List<Task> tasks) {
    final completedDates = tasks
        .where((t) => t.isCompleted && t.completedDate != null)
        .map((t) => DateTime(t.completedDate!.year, t.completedDate!.month, t.completedDate!.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (completedDates.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (!completedDates.contains(today) && !completedDates.contains(yesterday)) {
      return 0;
    }

    int streak = 0;
    DateTime currentCheck = completedDates.contains(today) ? today : yesterday;

    while (completedDates.contains(currentCheck)) {
      streak++;
      currentCheck = currentCheck.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Widget _buildCircularRing(
    String value,
    String label,
    double progress,
    Color color,
    IconData icon,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Soft background halo
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.05),
              ),
            ),
            SizedBox(
              width: 68,
              height: 68,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 7,
                backgroundColor: color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: _isDark ? 0.12 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: _isDark ? 0.3 : 0.18),
          width: 1.3,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _textPrimary,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      today.isNotEmpty ? "Today's Tasks" : 'Recent Tasks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${display.length}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (display.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View all',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (tp.isLoading)
              const ShimmerList(count: 3)
            else if (display.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.celebration_rounded,
                          size: 36,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "All Caught Up!",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "No pending tasks scheduled for today.",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
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
            Row(
              children: [
                Text(
                  'Upcoming Deadlines',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${upcoming.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...upcoming.map((t) => _buildUpcomingCard(t)),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    final statusText = task.isCompleted
        ? 'Completed'
        : (task.isOverdue ? 'Overdue' : 'Pending');

    final accentColor = task.isOverdue
        ? AppColors.error
        : task.isCompleted
            ? AppColors.success
            : AppColors.primary;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: task.isOverdue
                ? AppColors.error.withValues(alpha: 0.35)
                : task.isCompleted
                    ? AppColors.success.withValues(alpha: 0.25)
                    : (_isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.border.withValues(alpha: 0.7)),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: _isDark ? 0.12 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Status Accent Bar
            Container(
              width: 3.5,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),

            // Animated Toggle Checkbox
            GestureDetector(
              onTap: () async =>
                  await context.read<TaskProvider>().toggleComplete(task.id!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: task.isCompleted ? AppColors.success : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted
                        ? AppColors.success
                        : (_isDark ? Colors.white38 : AppColors.border),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 14),

            // Task Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isCompleted ? _textHint : _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12.5,
                        color: task.isOverdue ? AppColors.error : _textHint,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        DateFormatter.formatDueDate(task.dueDate),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: task.isOverdue ? AppColors.error : _textHint,
                          fontWeight: task.isOverdue
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge.fromStatus(statusText),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_ind_rounded, size: 13, color: _textHint),
                      const SizedBox(width: 5),
                      Text(
                        'Assigned ${DateFormatter.formatShort(task.assignedDate)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: _textHint,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        task.isOverdue ? Icons.warning_rounded : Icons.event_rounded,
                        size: 13,
                        color: task.isOverdue ? AppColors.error : _textHint,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Due ${DateFormatter.formatShort(task.dueDate)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          color: task.isOverdue ? AppColors.error : _textHint,
                          fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
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
                      context.read<TaskProvider>().clear();
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