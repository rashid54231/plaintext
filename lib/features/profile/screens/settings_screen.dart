import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/user_provider.dart';
import '../../auth/screens/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('Appearance', textSecondary),
            _buildCard(
              card,
              children: [
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return _switchTile(
                      icon: themeProvider.isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      iconColor: themeProvider.isDark
                          ? AppColors.primary
                          : AppColors.warning,
                      title: 'Dark Mode',
                      subtitle: themeProvider.isDark ? 'Currently dark' : 'Currently light',
                      value: themeProvider.isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionHeader('Account', textSecondary),
            _buildCard(
              card,
              children: [
                _navTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.primary,
                  title: 'Edit Profile',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => Navigator.of(context).pop(),
                ),
                _divider(),
                _navTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppColors.info,
                  title: 'Change Password',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _showChangePasswordDialog(context, isDark, card, textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionHeader('About', textSecondary),
            _buildCard(
              card,
              children: [
                _infoTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.info,
                  title: 'App Version',
                  value: '2.0.0',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _divider(),
                _infoTile(
                  icon: Icons.task_alt_rounded,
                  iconColor: AppColors.primary,
                  title: 'App Name',
                  value: 'TaskFlow',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionHeader('Danger Zone', textSecondary),
            _buildCard(
              card,
              children: [
                _navTile(
                  icon: Icons.logout_rounded,
                  iconColor: AppColors.error,
                  title: 'Logout',
                  titleColor: AppColors.error,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCard(Color card, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary)),
      subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: textSecondary)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? titleColor,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? textPrimary,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary)),
      trailing: Text(value, style: GoogleFonts.inter(fontSize: 13, color: textSecondary)),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 60, endIndent: 16);
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to logout?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<UserProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(
      BuildContext context, bool isDark, Color card, Color textPrimary) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text('Change Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textPrimary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                validator: (v) => v != newCtrl.text ? 'Does not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final success = await context.read<UserProvider>().updateProfile(
                currentPassword: currentCtrl.text,
                newPassword: newCtrl.text,
              );
              if (context.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Password updated!' : 'Current password incorrect'),
                    backgroundColor: success ? AppColors.success : AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Update', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
