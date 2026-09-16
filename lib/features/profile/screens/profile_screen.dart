import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user.dart';
import '../../../models/task.dart';
import '../../../providers/user_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../services/file_picker_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = context.read<UserProvider>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePickerService.instance.pickImages();
    if (result != null && result.files.isNotEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final userProvider = context.read<UserProvider>();
      final success = await userProvider.updateAvatar(result.files.first);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userProvider = context.read<UserProvider>();
    final success = await userProvider.updateProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (mounted && userProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userProvider.error!),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.plusJakartaSans()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign Out', style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<UserProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final isManager = user?.isManager ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.background;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          'User Profile',
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.heroGradient,
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded),
            tooltip: _isEditing ? 'Cancel Edit' : 'Edit Profile',
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) _loadUserData();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Avatar with Camera Edit Badge
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.heroGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(
                      child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: user.avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              errorWidget: (context, url, error) => _buildInitialAvatar(user),
                            )
                          : _buildInitialAvatar(user),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: card, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // User Name
            Text(
              user?.name ?? 'User',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6),

            // Role Badge (Slide 4 style: Gold Student / Manager)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isManager
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isManager
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isManager ? Icons.security_rounded : Icons.stars_rounded,
                    size: 15,
                    color: isManager ? AppColors.primary : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isManager ? 'PROJECT MANAGER' : 'GOLD STUDENT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isManager ? AppColors.primary : const Color(0xFFD97706),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isEditing)
              _buildEditForm(card)
            else ...[
              _buildMetricsGrid(user, card, textPrimary, textSecondary),
              const SizedBox(height: 16),
              _buildStreakBanner(card, textPrimary, textSecondary),
              const SizedBox(height: 16),
              _buildAchievementsCard(card, textPrimary, textSecondary),
              const SizedBox(height: 16),
              _buildProfileInfo(user, card, textPrimary, textSecondary),
              const SizedBox(height: 24),
              _buildLogoutButton(),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(User? user) {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Text(
          user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
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

  // Slide 4: Metric Statistics Grid
  Widget _buildMetricsGrid(User? user, Color card, Color textPrimary, Color textSecondary) {
    return Consumer2<TaskProvider, UserProvider>(
      builder: (context, tp, up, _) {
        final completed = tp.completedTasks;
        final totalTasks = tp.totalTasks;
        final points = completed * 10;
        final classCode = user?.classCode?.isNotEmpty == true 
            ? user!.classCode! 
            : (user?.isManager == true ? 'LEAD' : 'STUDENT');

        final streak = _calculateStreak(tp.userTasks);

        String rankText = '#1 Overall';
        if (user != null && !user.isManager && up.students.isNotEmpty) {
          final idx = up.students.indexWhere((s) => s.id == user.id);
          rankText = idx >= 0 ? '#${idx + 1} Overall' : '#1 Overall';
        } else if (user?.isManager == true) {
          rankText = 'Manager';
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _metricBox('COMPLETED TASKS', '$completed', card, textPrimary, textSecondary)),
                const SizedBox(width: 12),
                Expanded(child: _metricBox('ASSIGNMENTS DONE', '$totalTasks', card, textPrimary, textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metricBox('STREAK', '$streak Days', card, textPrimary, textSecondary, icon: '🔥')),
                const SizedBox(width: 12),
                Expanded(child: _metricBox('POINTS', '$points pts', card, textPrimary, textSecondary, icon: '⭐')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _metricBox('CLASS CODE', classCode, card, textPrimary, textSecondary)),
                const SizedBox(width: 12),
                Expanded(child: _metricBox('CURRENT RANK', rankText, card, textPrimary, textSecondary, icon: '🏆')),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _metricBox(String title, String value, Color card, Color textPrimary, Color textSecondary, {String? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (icon != null) ...[
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Slide 4: Streak Counter
  Widget _buildStreakBanner(Color card, Color textPrimary, Color textSecondary) {
    return Consumer<TaskProvider>(
      builder: (context, tp, _) {
        final streak = _calculateStreak(tp.userTasks);
        final streakTitle = streak > 0 ? '$streak Days on Fire!' : 'Complete tasks to ignite streak!';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STREAK COUNTER',
                      style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streakTitle,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: textPrimary),
                    ),
                  ],
                ),
              ),
              if (streak > 0)
                const Text('🔥🔥🔥', style: TextStyle(fontSize: 16)),
            ],
          ),
        );
      },
    );
  }

  // Slide 4: Achievements
  Widget _buildAchievementsCard(Color card, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACHIEVEMENTS & BADGES',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _achievementBadge('🏆', 'Gold Scholar', const Color(0xFFFFD700)),
              _achievementBadge('⭐', 'Consistent Pro', const Color(0xFF8B5CF6)),
              _achievementBadge('🎯', '100% On-Time', const Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _achievementBadge(String emoji, String title, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildProfileInfo(User? user, Color card, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        _buildInfoCard(Icons.person_outline, 'Full Name', user?.name ?? '', card, textPrimary, textSecondary),
        _buildInfoCard(Icons.email_outlined, 'Email', user?.email ?? '', card, textPrimary, textSecondary),
        _buildInfoCard(Icons.phone_outlined, 'Phone', user?.phone ?? 'Not set', card, textPrimary, textSecondary),
        if (user?.classCode != null && user!.classCode!.isNotEmpty)
          _buildInfoCard(Icons.school_outlined, 'Class Code', user.classCode!, card, textPrimary, textSecondary),
        _buildInfoCard(Icons.calendar_today_rounded, 'Joined', _formatDate(user?.createdAt), card, textPrimary, textSecondary),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value, Color card, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textSecondary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        label: Text(
          'Sign Out',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.error,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.error, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildEditForm(Color card) {
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your name',
              prefixIcon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone',
              hint: 'Enter phone number',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Save Changes',
              isLoading: _isLoading,
              onPressed: _handleUpdate,
              icon: Icons.save_rounded,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }
}
