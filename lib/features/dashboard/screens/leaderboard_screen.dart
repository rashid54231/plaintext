import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    await up.loadStudents();

    final futures = up.students.map((student) async {
      final statsFuture = DatabaseService.instance.getTaskCountByUser(student.id!);
      final marksFuture = DatabaseService.instance.getTotalMarksByUser(student.id!);
      final results = await Future.wait([statsFuture, marksFuture]);
      final stats = results[0] as Map<String, int>;
      final totalMarks = results[1] as int;
      int completed = stats['completed'] ?? 0;

      return {
        'name': student.name,
        'avatarUrl': student.avatarUrl,
        'points': totalMarks > 0 ? totalMarks : completed * 10,
        'completed': completed,
        'total': stats['total'] ?? 0,
      };
    });

    final data = (await Future.wait(futures)).toList();
    data.sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

    if (mounted) {
      setState(() {
        _leaderboardData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    // Slide 4: Space midnight dark theme
    const bg = Color(0xFF0A0E17);
    const cardColor = Color(0xFF141A29);
    const borderColor = Color(0xFF232C42);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar matching Slide 4: < STUDENT LEADERBOARD  [bell]
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (canPop)
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2234),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 36),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'STUDENT LEADERBOARD',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'TASKFLOW HALL OF FAME',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: const Color(0xFF818CF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2234),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: ShimmerList(count: 6),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadLeaderboard,
                      color: const Color(0xFF6366F1),
                      backgroundColor: cardColor,
                      child: _leaderboardData.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(40),
                              children: [
                                const SizedBox(height: 60),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: const Icon(Icons.emoji_events_outlined, size: 48, color: Color(0xFF818CF8)),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No Students Ranked Yet',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Students from the database will appear here dynamically as they complete tasks.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              children: [
                                // 3D Cylindrical Podium for Top 3
                                _build3DPodium(),
                                const SizedBox(height: 24),

                                if (_leaderboardData.length > 3) ...[
                                  // Section Header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'ALL RANKINGS',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      Text(
                                        '${_leaderboardData.length} Students',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Rankings 4th onwards
                                  ...List.generate(
                                    _leaderboardData.length - 3,
                                    (i) {
                                      final item = _leaderboardData[i + 3];
                                      return _buildRankCard(item, i + 4, cardColor, borderColor);
                                    },
                                  ),
                                ],
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 4: 3D Cylindrical Podium
  Widget _build3DPodium() {
    if (_leaderboardData.isEmpty) return const SizedBox.shrink();
    final first = _leaderboardData[0];
    final second = _leaderboardData.length > 1 ? _leaderboardData[1] : null;
    final third = _leaderboardData.length > 2 ? _leaderboardData[2] : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF232D42)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ambient Glow Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 8),
              Text(
                'TOP PERFORMERS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 3 Cylinders
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2nd Place: Silver (Left)
              Expanded(
                child: second != null
                    ? _buildCylinderColumn(
                        item: second,
                        rank: 2,
                        pedestalHeight: 90,
                        primaryColor: const Color(0xFFE2E8F0),
                        secondaryColor: const Color(0xFF64748B),
                        shadowColor: const Color(0xFF94A3B8),
                        trophyText: '🥈',
                        avatarSize: 26,
                      ).animate().slideY(begin: 0.2, duration: 400.ms)
                    : const SizedBox(),
              ),
              const SizedBox(width: 8),

              // 1st Place: Gold (Center Elevated)
              Expanded(
                child: _buildCylinderColumn(
                  item: first,
                  rank: 1,
                  pedestalHeight: 125,
                  primaryColor: const Color(0xFFFFDF00),
                  secondaryColor: const Color(0xFFB45309),
                  shadowColor: const Color(0xFFF59E0B),
                  trophyText: '👑',
                  avatarSize: 32,
                  isWinner: true,
                ).animate().slideY(begin: 0.3, duration: 500.ms),
              ),
              const SizedBox(width: 8),

              // 3rd Place: Bronze (Right)
              Expanded(
                child: third != null
                    ? _buildCylinderColumn(
                        item: third,
                        rank: 3,
                        pedestalHeight: 75,
                        primaryColor: const Color(0xFFF97316),
                        secondaryColor: const Color(0xFF7C2D12),
                        shadowColor: const Color(0xFFEA580C),
                        trophyText: '🥉',
                        avatarSize: 24,
                      ).animate().slideY(begin: 0.2, duration: 400.ms)
                    : const SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCylinderColumn({
    required Map<String, dynamic> item,
    required int rank,
    required double pedestalHeight,
    required Color primaryColor,
    required Color secondaryColor,
    required Color shadowColor,
    required String trophyText,
    required double avatarSize,
    bool isWinner = false,
  }) {
    final name = item['name'] as String;
    final points = item['points'] as int;
    final avatarUrl = item['avatarUrl'] as String?;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trophy / Crown Icon
        Text(trophyText, style: TextStyle(fontSize: isWinner ? 22 : 18)),
        const SizedBox(height: 4),

        // Glowing Avatar
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: primaryColor,
              width: isWinner ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: isWinner ? 0.5 : 0.25),
                blurRadius: isWinner ? 16 : 8,
                spreadRadius: isWinner ? 2 : 0,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: avatarSize,
            backgroundColor: const Color(0xFF1E293B),
            backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: avatarSize * 0.8,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),

        // Student Name
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: isWinner ? 13 : 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),

        // Points Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: shadowColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_formatNumber(points)} pts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 3D Cylindrical Pedestal
        Stack(
          alignment: Alignment.topCenter,
          children: [
            // Pedestal Body with 3D gradient
            Container(
              height: pedestalHeight,
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: isWinner ? 0.45 : 0.3),
                    secondaryColor.withValues(alpha: 0.2),
                    const Color(0xFF0F1523),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                  bottom: Radius.circular(8),
                ),
                border: Border.all(
                  color: primaryColor.withValues(alpha: isWinner ? 0.6 : 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$rank',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isWinner ? 30 : 24,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      shadows: [
                        Shadow(
                          color: shadowColor.withValues(alpha: 0.8),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'POINTS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: primaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // 3D Top Ellipse Cap
            Container(
              height: 16,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.9),
                    primaryColor.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Slide 4: Ranked Student Card
  Widget _buildRankCard(
    Map<String, dynamic> item,
    int rankIndex,
    Color cardColor,
    Color borderColor,
  ) {
    final name = item['name'] as String;
    final points = item['points'] as int;
    final completed = item['completed'] as int? ?? 0;
    final avatarUrl = item['avatarUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Center(
              child: Text(
                '#$rankIndex',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF1E293B),
            backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF818CF8),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name and completed tasks
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$completed tasks completed',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Points Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text(
                  '${_formatNumber(points)} pts',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(
          begin: 0.1,
          end: 0,
          delay: Duration(milliseconds: 25 * rankIndex),
        );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      final str = number.toString();
      final length = str.length;
      final result = StringBuffer();
      for (int i = 0; i < length; i++) {
        if (i > 0 && (length - i) % 3 == 0) {
          result.write(',');
        }
        result.write(str[i]);
      }
      return result.toString();
    }
    return number.toString();
  }
}
