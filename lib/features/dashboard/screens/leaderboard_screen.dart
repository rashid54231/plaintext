import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user.dart';
import '../../../providers/user_provider.dart';
import '../../../services/database_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboardData = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final up = context.read<UserProvider>();
    List<Map<String, dynamic>> data = [];
    
    for (var student in up.students) {
      final stats = await DatabaseService.instance.getTaskCountByUser(student.id!);
      // Use completed tasks as points if marks aren't explicitly assigned
      int points = stats['completed'] ?? 0; 
      // If we query sum of marks, we could do it here, but let's stick to simple logic or query it
      final totalMarks = await DatabaseService.instance.getTotalMarksByUser(student.id!);
      
      data.add({
        'student': student,
        'points': totalMarks > 0 ? totalMarks : points * 10, // Default 10 points per task if no marks
      });
    }
    
    data.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
    
    if (mounted) {
      setState(() {
        _leaderboardData = data;
        _isLoading = false;
      });
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? AppColors.backgroundDark : AppColors.background;
  Color get _card => _isDark ? AppColors.cardDark : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text('Leaderboard',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
            ),
            Expanded(
              child: _isLoading
                  ? const ShimmerList()
                  : _leaderboardData.isEmpty
                      ? Center(child: Text('No students available yet', style: GoogleFonts.inter(color: _textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _leaderboardData.length,
                          itemBuilder: (context, index) {
                            final item = _leaderboardData[index];
                            final student = item['student'] as User;
                            final points = item['points'] as int;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  Text('#${index + 1}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: index < 3 ? AppColors.primary : AppColors.textHint)),
                                  const SizedBox(width: 16),
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: index == 0 ? const Color(0xFFFFD700).withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: index == 0 ? const Color(0xFFDAA520) : AppColors.primary)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(student.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _textPrimary)),
                                        Text('$points Points', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
                                      ],
                                    ),
                                  ),
                                  if (index == 0)
                                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD700), size: 28),
                                ],
                              ),
                            ).animate().fade().slideY(begin: 0.1, end: 0, delay: Duration(milliseconds: 50 * index));
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
