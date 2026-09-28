import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../models/user.dart';
import '../../../models/comment.dart';
import '../../../models/task_assignment.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/database_service.dart';
import '../../../services/file_picker_service.dart';
import '../../../shared/widgets/custom_button.dart';
import 'create_task_screen.dart';
import 'task_comments_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task _task;
  List<String> _uploadedFiles = [];
  bool _isUploading = false;
  bool _isLoadingFiles = true;
  int _commentCount = 0;
  List<TaskAssignment> _assignments = [];
  bool _isLoadingAssignments = true;
  TaskAssignment? _myAssignment;
  String _assignmentFilter = 'All';
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadFiles();
    _loadCommentCount();
    _loadAssignments();
    _initCountdown();
  }

  void _initCountdown() {
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final diff = _task.dueDate.difference(now);
    setState(() {
      _timeRemaining = diff;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    final currentUser = context.read<UserProvider>().currentUser;
    try {
      final list = await DatabaseService.instance.getTaskAssignments(_task.id!);
      TaskAssignment? myAssign;
      if (currentUser != null) {
        final match = list.where((a) => a.userId == currentUser.id);
        if (match.isNotEmpty) myAssign = match.first;
      }
      if (mounted) {
        setState(() {
          _assignments = list;
          _myAssignment = myAssign;
          if (myAssign != null && myAssign.submissionPaths.isNotEmpty) {
            _uploadedFiles = List.from(myAssign.submissionPaths);
          }
          _isLoadingAssignments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAssignments = false);
    }
  }

  Future<void> _loadFiles() async {
    final files = await FilePickerService.instance.getTaskFiles(_task.id!);
    if (mounted) setState(() { _uploadedFiles = files; _isLoadingFiles = false; });
  }

  Future<void> _loadCommentCount() async {
    final comments = await DatabaseService.instance.getComments(_task.id!);
    if (mounted) setState(() => _commentCount = comments.length);
  }

  Future<void> _pickAndUploadFile() async {
    final user = context.read<UserProvider>().currentUser;
    final taskProvider = context.read<TaskProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FilePickerService.instance.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;
      setState(() => _isUploading = true);
      final urls = await FilePickerService.instance.uploadMultipleFiles(
        taskId: _task.id!, files: result.files);
      _uploadedFiles.addAll(urls);
      
      if (user != null) {
        await taskProvider.submitStudentAssignment(
          taskId: _task.id!,
          userId: user.id!,
          submissionPaths: _uploadedFiles,
        );
        await _loadAssignments();
      } else {
        final updatedTask = _task.copyWith(submissionPaths: _uploadedFiles);
        await taskProvider.updateTask(updatedTask);
        if (mounted) setState(() => _task = updatedTask);
      }
      
      if (mounted) setState(() => _isUploading = false);
      messenger.showSnackBar(SnackBar(
        content: Text('${result.files.length} file(s) uploaded successfully!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Future<void> _downloadFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color get _priorityColor {
    switch (_task.priority) {
      case Priority.high: return AppColors.highPriority;
      case Priority.medium: return AppColors.mediumPriority;
      case Priority.low: return AppColors.lowPriority;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isManager = context.watch<UserProvider>().isManager;
    final bg = isDark ? AppColors.backgroundDark : AppColors.background;
    final card = isDark ? AppColors.cardDark : Colors.white;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final textHint = isDark ? AppColors.textHintDark : AppColors.textHint;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Comments button
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.chat_bubble_outline_rounded, color: textPrimary),
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TaskCommentsScreen(
                      taskId: _task.id!, taskTitle: _task.title)));
                  _loadCommentCount();
                },
              ),
              if (_commentCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: Text('$_commentCount', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          if (isManager) ...[
            IconButton(
              icon: Icon(Icons.edit_rounded, color: textPrimary),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CreateTaskScreen(editTask: _task)));
                final updated = await DatabaseService.instance.getTaskById(_task.id!);
                if (updated != null && mounted) setState(() => _task = updated);
              },
            ),
            IconButton(icon: Icon(Icons.delete_rounded, color: textPrimary), onPressed: _handleDelete),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(textPrimary, textSecondary),
            const SizedBox(height: 14),
            _buildCountdownTimerSection(card, textPrimary, textSecondary),
            const SizedBox(height: 16),
            _buildStatusTracker(card, textPrimary, textSecondary),
            const SizedBox(height: 16),
            _buildInfoSection(card, textPrimary, textHint),
            const SizedBox(height: 16),
            _buildDescriptionSection(card, textPrimary, textSecondary),
            if (_task.subtasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSubtasksChecklistSection(card, textPrimary, textSecondary),
            ],
            const SizedBox(height: 16),
            _buildDatesSection(card, textHint),
            const SizedBox(height: 16),
            if (isManager)
              _buildManagerSubmissionsGrid(card, textPrimary, textSecondary, textHint)
            else
              _buildSubmissionSection(isManager, card, textPrimary, textHint),
            const SizedBox(height: 16),
            _buildCommentsPreviewSection(card, textPrimary, textSecondary),
            if (!isManager && ((_myAssignment?.reviewComment != null && _myAssignment!.reviewComment!.isNotEmpty) || (_task.reviewComment != null && _task.reviewComment!.isNotEmpty))) ...[
              const SizedBox(height: 16),
              _buildReviewSection(card, textPrimary, textSecondary),
            ],
            const SizedBox(height: 24),
            if (!isManager) _buildStudentActions(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Slide 2: Minimal Elegant Header with Title & Task ID
  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    final taskCode = _task.id != null && _task.id!.length >= 4
        ? _task.id!.substring(0, 4).toUpperCase()
        : '104';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _task.title.isNotEmpty ? _task.title : 'Design Marketing Campaign',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'ID: TF-$taskCode',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _priorityColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _task.priority.name.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _priorityColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection(Color card, Color textPrimary, Color textHint) {
    return FutureBuilder<List<User>>(
      future: DatabaseService.instance.getTaskAssignedUsers(_task.id!),
      builder: (context, snap1) => FutureBuilder<User?>(
        future: DatabaseService.instance.getUserById(_task.assignedByUserId),
        builder: (context, snap2) {
          final users = snap1.data ?? [];
          final manager = snap2.data;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _infoRow(Icons.people_rounded, 'Assigned To (${users.length})',
                    users.isEmpty ? 'Loading...' : users.map((u) => u.name).join(', '),
                    AppColors.info, textPrimary, textHint),
                const Divider(height: 24),
                _infoRow(Icons.admin_panel_settings_rounded, 'Assigned By',
                    manager?.name ?? 'Loading...', AppColors.primary, textPrimary, textHint),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color, Color textPrimary, Color textHint) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: textHint)),
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(Color card, Color textPrimary, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Description', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
          ]),
          const SizedBox(height: 12),
          Text(
            _task.description.isNotEmpty ? _task.description : 'No description provided',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _task.description.isNotEmpty ? textSecondary : AppColors.textHint,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection(Color card, Color textHint) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _dateRow(Icons.assignment_rounded, 'Assigned',
              DateFormatter.formatDateTime(_task.assignedDate), AppColors.info),
          const Divider(height: 20),
          _dateRow(Icons.event_rounded, 'Due Date',
              DateFormatter.formatDateTime(_task.dueDate),
              _task.isOverdue ? AppColors.error : AppColors.warning),
          if (_task.completedDate != null) ...[
            const Divider(height: 20),
            _dateRow(Icons.check_circle_rounded, 'Completed',
                DateFormatter.formatDateTime(_task.completedDate!), AppColors.success),
          ],
          const Divider(height: 20),
          _dateRow(
            Icons.schedule_rounded,
            _task.isOverdue ? 'Overdue By' : 'Days Until Due',
            _task.isOverdue
                ? '${-_task.daysUntilDue} day(s)'
                : _task.daysUntilDue == 0
                    ? 'Due today'
                    : '${_task.daysUntilDue} day(s)',
            _task.isOverdue ? AppColors.error : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _dateRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textHint)),
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTracker(Color card, Color textPrimary, Color textSecondary) {
    int currentStep = 0;
    if (_task.isCompleted) {
      currentStep = 3;
    } else if ((_task.reviewComment != null && _task.reviewComment!.isNotEmpty) || _uploadedFiles.isNotEmpty) {
      currentStep = 2;
    } else if (_task.status == TaskStatus.inProgress) {
      currentStep = 1;
    } else {
      currentStep = 0;
    }

    final steps = ['Backlog', 'In Progress', 'Review', 'Completed'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alt_route_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Real-Time Status Tracker',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (_task.isCompleted ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  steps[currentStep],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _task.isCompleted ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index.isOdd) {
                final lineIndex = index ~/ 2;
                final isPassed = lineIndex < currentStep;
                return Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isPassed ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              } else {
                final stepIndex = index ~/ 2;
                final isCompletedStep = stepIndex < currentStep;
                final isCurrent = stepIndex == currentStep;

                Color nodeColor = AppColors.border;
                if (isCompletedStep) {
                  nodeColor = AppColors.success;
                } else if (isCurrent) {
                  nodeColor = AppColors.primary;
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCompletedStep || isCurrent ? nodeColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompletedStep || isCurrent ? nodeColor : AppColors.border,
                          width: 2,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: isCompletedStep
                            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                            : Text(
                                '${stepIndex + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isCurrent ? Colors.white : AppColors.textHint,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[stepIndex],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? textPrimary : textSecondary,
                      ),
                    ),
                  ],
                );
              }
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownTimerSection(Color card, Color textPrimary, Color textSecondary) {
    final isDone = _task.isCompleted || (_myAssignment?.isCompleted ?? false);
    final isOverdue = _timeRemaining.isNegative && !isDone;

    if (isDone) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assignment Completed',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    'Great job! This task has been submitted and completed.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final totalSeconds = _timeRemaining.inSeconds.abs();
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final isUrgent = !isOverdue && days == 0 && hours < 24;
    final accentColor = isOverdue
        ? AppColors.error
        : (isUrgent ? AppColors.warning : AppColors.primary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isOverdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isOverdue ? 'Deadline Expired / Overdue' : 'Live Deadline Countdown',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOverdue ? 'LATE' : (isUrgent ? 'DUE SOON' : 'ACTIVE'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCountdownBox('$days', 'DAYS', accentColor, textPrimary),
              _countdownSeparator(accentColor),
              _buildCountdownBox(hours.toString().padLeft(2, '0'), 'HOURS', accentColor, textPrimary),
              _countdownSeparator(accentColor),
              _buildCountdownBox(minutes.toString().padLeft(2, '0'), 'MINS', accentColor, textPrimary),
              _countdownSeparator(accentColor),
              _buildCountdownBox(seconds.toString().padLeft(2, '0'), 'SECS', accentColor, textPrimary),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Due: ${DateFormatter.formatDateTime(_task.dueDate)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBox(String val, String label, Color accent, Color textPrimary) {
    return Column(
      children: [
        Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Center(
            child: Text(
              val,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
      ],
    );
  }

  Widget _countdownSeparator(Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        ':',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: accent.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildSubtasksChecklistSection(Color card, Color textPrimary, Color textSecondary) {
    final subtasks = _task.subtasks;
    final completedCount = _task.completedSubtasksCount;
    final totalCount = subtasks.length;
    final progress = _task.subtasksProgress;
    final pct = (progress * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Subtasks Checklist',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (progress == 1.0 ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$completedCount / $totalCount ($pct%)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: progress == 1.0 ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...subtasks.asMap().entries.map((entry) {
            final idx = entry.key;
            final sub = entry.value;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final updatedList = List<SubTask>.from(_task.subtasks);
                updatedList[idx] = sub.copyWith(isCompleted: !sub.isCompleted);
                final updatedTask = _task.copyWith(subtasks: updatedList);
                setState(() => _task = updatedTask);
                await context.read<TaskProvider>().updateTask(updatedTask);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      sub.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: sub.isCompleted ? AppColors.success : AppColors.textHint,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sub.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: sub.isCompleted ? AppColors.textHint : textPrimary,
                          decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubmissionSection(bool isManager, Color card, Color textPrimary, Color textHint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.attach_file_rounded, color: AppColors.secondary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Attachments & Files', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
              const Spacer(),
              if (_uploadedFiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_uploadedFiles.length}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingFiles)
            const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          else if (_uploadedFiles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 34, color: textHint),
                  const SizedBox(height: 8),
                  Text('No files attached yet', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textHint)),
                ],
              ),
            )
          else
            ...List.generate(_uploadedFiles.length, (i) {
              final url = _uploadedFiles[i];
              final lowerUrl = url.toLowerCase();
              final fileName = url.split('/').last.split('?').first;
              
              String fileType = 'FILE';
              Color badgeColor = AppColors.info;
              IconData fileIcon = Icons.insert_drive_file_rounded;

              if (lowerUrl.contains('.pdf')) {
                fileType = 'PDF';
                badgeColor = const Color(0xFFEF4444);
                fileIcon = Icons.picture_as_pdf_rounded;
              } else if (lowerUrl.contains('.zip') || lowerUrl.contains('.rar') || lowerUrl.contains('.tar')) {
                fileType = 'ZIP';
                badgeColor = const Color(0xFFF59E0B);
                fileIcon = Icons.folder_zip_rounded;
              } else if (lowerUrl.contains('.doc') || lowerUrl.contains('.docx') || lowerUrl.contains('.txt')) {
                fileType = 'DOC';
                badgeColor = const Color(0xFF3B82F6);
                fileIcon = Icons.article_rounded;
              } else if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => lowerUrl.contains(e))) {
                fileType = 'IMG';
                badgeColor = const Color(0xFF10B981);
                fileIcon = Icons.image_rounded;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _previewFile(url, fileName),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.03)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(fileIcon, color: badgeColor, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              fileType,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName.length > 26 ? '${fileName.substring(0, 26)}...' : fileName,
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary, size: 18),
                        onPressed: () => _previewFile(url, fileName),
                        tooltip: 'Preview File',
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward_rounded, color: AppColors.primary, size: 20),
                        onPressed: () => _downloadFile(url),
                        tooltip: 'Download File',
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCommentsPreviewSection(Color card, Color textPrimary, Color textSecondary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.forum_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Discussion Thread', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TaskCommentsScreen(taskId: _task.id!, taskTitle: _task.title),
                  ));
                  _loadCommentCount();
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AppColors.primary),
                label: Text('Open Chat', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<TaskComment>>(
            future: DatabaseService.instance.getComments(_task.id!),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];
              if (comments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No comments yet. Tap Open Chat to start the discussion.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textHint)),
                );
              }
              final recent = comments.take(2).toList();
              return Column(
                children: recent.map((c) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.03)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            c.userName.isNotEmpty ? c.userName[0].toUpperCase() : '?',
                            style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.userName, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary)),
                              const SizedBox(height: 2),
                              Text(c.message, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(Color card, Color textPrimary, Color textSecondary) {
    final comment = _myAssignment?.reviewComment ?? _task.reviewComment;
    final marks = _myAssignment?.marks ?? _task.marks;
    if (comment == null || comment.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_rounded, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Text(
                'Teacher Feedback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              if (marks != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Grade: $marks${_task.maxMarks != null ? ' / ${_task.maxMarks}' : ''}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentActions() {
    final isDone = _myAssignment?.isCompleted ?? _task.isCompleted;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickAndUploadFile,
            icon: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.upload_file_rounded, color: AppColors.primary),
            label: Text(
              _isUploading ? 'Uploading...' : 'Upload Assignment Files',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (!isDone) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Submit Assignment',
              onPressed: () async {
                final user = context.read<UserProvider>().currentUser;
                if (user == null) return;
                final success = await context.read<TaskProvider>().submitStudentAssignment(
                  taskId: _task.id!,
                  userId: user.id!,
                  submissionPaths: _uploadedFiles,
                );
                if (success && mounted) {
                  _loadAssignments();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Assignment submitted successfully! 🎉'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              },
              backgroundColor: AppColors.success,
              icon: Icons.send_rounded,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManagerSubmissionsGrid(Color card, Color textPrimary, Color textSecondary, Color textHint) {
    final totalAssigned = _assignments.length;
    final submittedCount = _assignments.where((a) => a.isCompleted || a.status == 'submitted').length;
    final gradedCount = _assignments.where((a) => a.marks != null || a.status == 'completed').length;
    final pendingCount = _assignments.where((a) => !a.isCompleted && a.status != 'submitted').length;

    List<TaskAssignment> filtered = _assignments;
    if (_assignmentFilter == 'Submitted') {
      filtered = _assignments.where((a) => a.isCompleted || a.status == 'submitted').toList();
    } else if (_assignmentFilter == 'Graded') {
      filtered = _assignments.where((a) => a.marks != null || a.status == 'completed').toList();
    } else if (_assignmentFilter == 'Pending') {
      filtered = _assignments.where((a) => !a.isCompleted && a.status != 'submitted').toList();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Submissions & Grading',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '$totalAssigned student(s) assigned',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: textHint,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_download_outlined, size: 20, color: AppColors.primary),
                onPressed: _exportGradeReport,
                tooltip: 'Export Grade Report (CSV)',
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
                onPressed: _loadAssignments,
                tooltip: 'Refresh Submissions',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Mini statistics badges
          Row(
            children: [
              _buildMiniStatChip('Submitted', '$submittedCount', AppColors.info, Icons.upload_file_rounded),
              const SizedBox(width: 8),
              _buildMiniStatChip('Graded', '$gradedCount', AppColors.success, Icons.star_rounded),
              const SizedBox(width: 8),
              _buildMiniStatChip('Pending', '$pendingCount', AppColors.warning, Icons.hourglass_top_rounded),
            ],
          ),
          const SizedBox(height: 14),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Submitted', 'Graded', 'Pending'].map((filter) {
                final isSelected = _assignmentFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter,
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
                        : AppColors.background,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide.none,
                    onSelected: (val) => setState(() => _assignmentFilter = filter),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          if (_isLoadingAssignments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            )
          else if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 36, color: textHint),
                  const SizedBox(height: 8),
                  Text(
                    _assignments.isEmpty
                        ? 'No students assigned yet'
                        : 'No submissions in "$_assignmentFilter" filter',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: textHint),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((assignment) => _buildStudentAssignmentCard(assignment, textPrimary, textSecondary, textHint)),
        ],
      ),
    );
  }

  Widget _buildMiniStatChip(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
            Text(
              '$label: ',
              style: GoogleFonts.plusJakartaSans(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAssignmentCard(
    TaskAssignment a,
    Color textPrimary,
    Color textSecondary,
    Color textHint,
  ) {
    final isGraded = a.marks != null;
    final isSubmitted = a.isCompleted || a.status == 'submitted';
    final hasFiles = a.submissionPaths.isNotEmpty;

    Color statusColor = AppColors.warning;
    String statusText = 'Pending';
    if (isGraded) {
      statusColor = AppColors.success;
      statusText = 'Graded (${a.marks}${_task.maxMarks != null ? '/${_task.maxMarks}' : ''})';
    } else if (isSubmitted) {
      statusColor = AppColors.info;
      statusText = 'Submitted';
    } else if (a.status == 'rejected') {
      statusColor = AppColors.error;
      statusText = 'Needs Revision';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGraded
              ? AppColors.success.withValues(alpha: 0.3)
              : (isSubmitted ? AppColors.info.withValues(alpha: 0.3) : AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage: (a.userAvatarUrl != null && a.userAvatarUrl!.isNotEmpty)
                    ? NetworkImage(a.userAvatarUrl!)
                    : null,
                child: (a.userAvatarUrl == null || a.userAvatarUrl!.isEmpty)
                    ? Text(
                        (a.userName != null && a.userName!.isNotEmpty)
                            ? a.userName![0].toUpperCase()
                            : 'S',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.userName ?? 'Student',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      a.userEmail ?? '',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: textHint),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          // Submitted timestamp if available
          if (a.submittedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 13, color: textHint),
                const SizedBox(width: 4),
                Text(
                  'Submitted: ${DateFormatter.formatDateTime(a.submittedAt!)}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: textHint),
                ),
              ],
            ),
          ],

          // Attached Files
          if (hasFiles) ...[
            const SizedBox(height: 10),
            Text(
              'Attached Files (${a.submissionPaths.length}):',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...a.submissionPaths.map((url) {
              final lowerUrl = url.toLowerCase();
              final fileName = url.split('/').last.split('?').first;

              Color fileColor = AppColors.info;
              IconData fileIcon = Icons.insert_drive_file_rounded;
              if (lowerUrl.contains('.pdf')) {
                fileColor = const Color(0xFFEF4444);
                fileIcon = Icons.picture_as_pdf_rounded;
              } else if (lowerUrl.contains('.doc') || lowerUrl.contains('.docx')) {
                fileColor = const Color(0xFF3B82F6);
                fileIcon = Icons.article_rounded;
              } else if (['.jpg', '.jpeg', '.png', '.webp'].any((e) => lowerUrl.contains(e))) {
                fileColor = const Color(0xFF10B981);
                fileIcon = Icons.image_rounded;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _previewFile(url, fileName),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: fileColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(fileIcon, color: fileColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fileName.length > 30 ? '${fileName.substring(0, 30)}...' : fileName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_red_eye_outlined, size: 16, color: fileColor),
                        onPressed: () => _previewFile(url, fileName),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        tooltip: 'Preview File',
                      ),
                      IconButton(
                        icon: Icon(Icons.open_in_new_rounded, size: 16, color: fileColor),
                        onPressed: () => _downloadFile(url),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Open File',
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else if (isSubmitted) ...[
            const SizedBox(height: 8),
            Text(
              'No files attached with submission',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontStyle: FontStyle.italic, color: textHint),
            ),
          ],

          // Feedback quote if already reviewed
          if (a.reviewComment != null && a.reviewComment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: AppColors.info, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Teacher Feedback:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.info),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.reviewComment!,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Action button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showGradingDialog(a),
              icon: Icon(
                isGraded ? Icons.edit_note_rounded : Icons.rate_review_rounded,
                size: 16,
                color: isGraded ? AppColors.success : AppColors.primary,
              ),
              label: Text(
                isGraded ? 'Update Grade & Review' : 'Grade Submission',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isGraded ? AppColors.success : AppColors.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(
                  color: isGraded ? AppColors.success : AppColors.primary,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGradingDialog(TaskAssignment assignment) {
    final marksCtrl = TextEditingController(text: assignment.marks?.toString() ?? '');
    final feedbackCtrl = TextEditingController(text: assignment.reviewComment ?? '');
    bool isApproved = assignment.status != 'rejected';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final sheetBg = isDark ? AppColors.cardDark : Colors.white;
          final tPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
          final tSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            (assignment.userName != null && assignment.userName!.isNotEmpty)
                                ? assignment.userName![0].toUpperCase()
                                : 'S',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignment.userName ?? 'Student',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: tPrimary,
                                ),
                              ),
                              Text(
                                assignment.userEmail ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: tSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Text(
                      'Score / Marks',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: marksCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: _task.maxMarks != null
                            ? 'Enter marks (out of ${_task.maxMarks})'
                            : 'Enter marks (e.g. 10)',
                        prefixIcon: const Icon(Icons.star_rounded, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Review Feedback & Comments',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: feedbackCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add constructive feedback for this student...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Decision',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Approve & Pass'),
                          selected: isApproved,
                          selectedColor: AppColors.success.withValues(alpha: 0.2),
                          onSelected: (val) => setModalState(() => isApproved = true),
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('Needs Revision'),
                          selected: !isApproved,
                          selectedColor: AppColors.warning.withValues(alpha: 0.2),
                          onSelected: (val) => setModalState(() => isApproved = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: isSubmitting ? 'Saving...' : 'Save Grade & Feedback',
                        isLoading: isSubmitting,
                        onPressed: () {
                          if (isSubmitting) return;
                          final parsedMarks = int.tryParse(marksCtrl.text.trim());
                          if (_task.maxMarks != null &&
                              parsedMarks != null &&
                              parsedMarks > _task.maxMarks!) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Marks cannot exceed max marks (${_task.maxMarks})'),
                              backgroundColor: AppColors.error,
                            ));
                            return;
                          }
                          setModalState(() => isSubmitting = true);
                          final taskProvider = context.read<TaskProvider>();
                          final messenger = ScaffoldMessenger.of(context);

                          final navigator = Navigator.of(ctx);
                          taskProvider.gradeStudentAssignment(
                            taskId: _task.id!,
                            userId: assignment.userId,
                            marks: parsedMarks,
                            reviewComment: feedbackCtrl.text.trim().isNotEmpty
                                ? feedbackCtrl.text.trim()
                                : (isApproved ? 'Well done!' : 'Needs revision.'),
                            approved: isApproved,
                          ).then((success) {
                            if (mounted) {
                              setModalState(() => isSubmitting = false);
                              if (success) {
                                navigator.pop();
                                _loadAssignments();
                                messenger.showSnackBar(SnackBar(
                                  content: Text('Grade saved for ${assignment.userName ?? 'Student'}!'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _previewFile(String url, String fileName) {
    final lowerUrl = url.toLowerCase();
    final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp'].any((e) => lowerUrl.contains(e));

    if (isImage) {
      showDialog(
        context: context,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      onPressed: () => _downloadFile(url),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      placeholder: (c, u) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      errorWidget: (c, u, e) => Container(
                        padding: const EdgeInsets.all(30),
                        color: Colors.black54,
                        child: const Column(
                          children: [
                            Icon(Icons.broken_image_rounded, color: Colors.white70, size: 48),
                            SizedBox(height: 8),
                            Text('Failed to load image', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Document Preview Modal Sheet
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final sheetBg = isDark ? AppColors.cardDark : Colors.white;
          final tPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
          final tSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

          IconData docIcon = Icons.insert_drive_file_rounded;
          Color docColor = AppColors.info;
          String typeName = 'Document File';

          if (lowerUrl.contains('.pdf')) {
            docIcon = Icons.picture_as_pdf_rounded;
            docColor = const Color(0xFFEF4444);
            typeName = 'Adobe PDF Document';
          } else if (lowerUrl.contains('.doc') || lowerUrl.contains('.docx')) {
            docIcon = Icons.article_rounded;
            docColor = const Color(0xFF3B82F6);
            typeName = 'Word Document';
          } else if (lowerUrl.contains('.zip') || lowerUrl.contains('.rar')) {
            docIcon = Icons.folder_zip_rounded;
            docColor = const Color(0xFFF59E0B);
            typeName = 'Archive File';
          }

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: docColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(docIcon, color: docColor, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  fileName,
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: tPrimary),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  typeName,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: tSecondary),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Link'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('File link copied to clipboard!')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                        label: const Text('Open / View'),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _downloadFile(url);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _exportGradeReport() {
    if (_assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student assignments available to export.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('"Student Name","Email","Status","Submitted At","Marks","Max Marks","Feedback"');

    for (final a in _assignments) {
      final name = (a.userName ?? 'Student').replaceAll('"', '""');
      final email = (a.userEmail ?? '').replaceAll('"', '""');
      final status = (a.isCompleted || a.status == 'completed'
              ? 'Graded'
              : (a.submittedAt != null || a.status == 'submitted' ? 'Submitted' : 'Pending'))
          .replaceAll('"', '""');
      final submitted = (a.submittedAt != null ? DateFormatter.formatDateTime(a.submittedAt!) : 'N/A')
          .replaceAll('"', '""');
      final marks = a.marks != null ? '${a.marks}' : 'N/A';
      final maxMarks = _task.maxMarks != null ? '${_task.maxMarks}' : 'N/A';
      final feedback = (a.reviewComment ?? '').replaceAll('"', '""');

      buffer.writeln('"$name","$email","$status","$submitted","$marks","$maxMarks","$feedback"');
    }

    final csvText = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.table_chart_rounded, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Export Grade Report',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generated CSV report for ${_assignments.length} student(s):',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textHint),
              ),
              const SizedBox(height: 12),
              Container(
                height: 140,
                width: double.maxFinite,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    csvText,
                    style: GoogleFonts.firaCode(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy CSV'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csvText));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Grade report CSV copied to clipboard! Paste into Excel or Google Sheets.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _handleDelete() {
    final taskProvider = context.read<TaskProvider>();
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Task', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        content: Text('Delete "${_task.title}"?', style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FilePickerService.instance.deleteTaskFiles(_task.id!);
              final success = await taskProvider.deleteTask(_task.id!);
              if (success && mounted) nav.pop();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
