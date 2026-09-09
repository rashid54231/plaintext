import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user.dart';
import '../../../providers/user_provider.dart';
import '../../../services/database_service.dart';
import '../../../shared/widgets/shimmer_loader.dart';

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
      final stats =
          await DatabaseService.instance.getTaskCountByUser(student.id!);
      int points = stats['completed'] ?? 0;
      final totalMarks =
          await DatabaseService.instance.getTotalMarksByUser(student.id!);

      data.add({
        'student': student,
        'points': totalMarks > 0 ? totalMarks : points * 10,
        'completed': stats['completed'] ?? 0,
        'total': stats['total'] ?? 0,
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
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          'Hall of Fame',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLeaderboard,
            tooltip: 'Refresh Rankings',
          ),
        ],
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerList(count: 6),
            )
          : _leaderboardData.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 64, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text(
                        'No students ranked yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLeaderboard,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      if (_leaderboardData.length >= 3) ...[
                        _buildPodium(),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        _leaderboardData.length >= 3
                            ? 'All Rankings'
                            : 'Rankings',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(
                        _leaderboardData.length >= 3
                            ? _leaderboardData.length - 3
                            : _leaderboardData.length,
                        (i) {
                          final actualIndex =
                              _leaderboardData.length >= 3 ? i + 3 : i;
                          final item = _leaderboardData[actualIndex];
                          return _buildRankItem(item, actualIndex);
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPodium() {
    final first = _leaderboardData[0];
    final second = _leaderboardData[1];
    final third = _leaderboardData[2];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
              : [const Color(0xFFEEF2FF), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stars_rounded,
                  color: Color(0xFFFFD700), size: 22),
              const SizedBox(width: 8),
              Text(
                'Top Performers',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2nd Place (Silver)
              Expanded(
                child: _buildPodiumColumn(
                  item: second,
                  rank: 2,
                  badgeColor: const Color(0xFF94A3B8),
                  badgeIcon: '🥈',
                  pedestalHeight: 80,
                  avatarRadius: 26,
                ).animate().slideY(begin: 0.3, duration: 500.ms),
              ),
              const SizedBox(width: 8),
              // 1st Place (Gold)
              Expanded(
                child: _buildPodiumColumn(
                  item: first,
                  rank: 1,
                  badgeColor: const Color(0xFFFFD700),
                  badgeIcon: '👑',
                  pedestalHeight: 110,
                  avatarRadius: 32,
                  isWinner: true,
                ).animate().slideY(begin: 0.4, duration: 600.ms),
              ),
              const SizedBox(width: 8),
              // 3rd Place (Bronze)
              Expanded(
                child: _buildPodiumColumn(
                  item: third,
                  rank: 3,
                  badgeColor: const Color(0xFFCD7F32),
                  badgeIcon: '🥉',
                  pedestalHeight: 65,
                  avatarRadius: 24,
                ).animate().slideY(begin: 0.3, duration: 500.ms),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required Map<String, dynamic> item,
    required int rank,
    required Color badgeColor,
    required String badgeIcon,
    required double pedestalHeight,
    required double avatarRadius,
    bool isWinner = false,
  }) {
    final student = item['student'] as User;
    final points = item['points'] as int;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          badgeIcon,
          style: TextStyle(fontSize: isWinner ? 24 : 18),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor, width: isWinner ? 3 : 2),
            boxShadow: [
              if (isWinner)
                BoxShadow(
                  color: badgeColor.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: badgeColor.withValues(alpha: 0.15),
            backgroundImage: student.avatarUrl != null
                ? CachedNetworkImageProvider(student.avatarUrl!)
                : null,
            child: student.avatarUrl == null
                ? Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: avatarRadius * 0.7,
                      fontWeight: FontWeight.bold,
                      color: isWinner ? badgeColor : _textPrimary,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          student.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isWinner ? 13 : 12,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$points pts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isWinner ? const Color(0xFFB45309) : _textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: pedestalHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                badgeColor.withValues(alpha: 0.35),
                badgeColor.withValues(alpha: 0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isWinner ? const Color(0xFFB45309) : _textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankItem(Map<String, dynamic> item, int index) {
    final student = item['student'] as User;
    final points = item['points'] as int;
    final completed = item['completed'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '#${index + 1}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: student.avatarUrl != null
                ? CachedNetworkImageProvider(student.avatarUrl!)
                : null,
            child: student.avatarUrl == null
                ? Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  '$completed tasks completed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$points pts',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(
          begin: 0.1,
          end: 0,
          delay: Duration(milliseconds: 30 * index),
        );
  }
}
