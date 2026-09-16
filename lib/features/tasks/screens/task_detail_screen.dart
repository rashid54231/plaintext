import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../models/user.dart';
import '../../../models/comment.dart';
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

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadFiles();
    _loadCommentCount();
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
    try {
      final result = await FilePickerService.instance.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;
      setState(() => _isUploading = true);
      final urls = await FilePickerService.instance.uploadMultipleFiles(
        taskId: _task.id!, files: result.files);
      _uploadedFiles.addAll(urls);
      final updatedTask = _task.copyWith(submissionPaths: _uploadedFiles);
      await context.read<TaskProvider>().updateTask(updatedTask);
      setState(() { _task = updatedTask; _isUploading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${result.files.length} file(s) uploaded'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
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
            const SizedBox(height: 18),
            _buildStatusTracker(card, textPrimary, textSecondary),
            const SizedBox(height: 16),
            _buildInfoSection(card, textPrimary, textHint),
            const SizedBox(height: 16),
            _buildDescriptionSection(card, textPrimary, textSecondary),
            const SizedBox(height: 16),
            _buildDatesSection(card, textHint),
            const SizedBox(height: 16),
            _buildSubmissionSection(isManager, card, textPrimary, textHint),
            const SizedBox(height: 16),
            _buildCommentsPreviewSection(card, textPrimary, textSecondary),
            if (_task.reviewComment != null && _task.reviewComment!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildReviewSection(card, textPrimary, textSecondary),
            ],
            const SizedBox(height: 24),
            if (!isManager) _buildStudentActions(),
            if (isManager) _buildManagerActions(),
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

              return Container(
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
                      icon: const Icon(Icons.arrow_downward_rounded, color: AppColors.primary, size: 20),
                      onPressed: () => _downloadFile(url),
                      tooltip: 'Download File',
                    ),
                  ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.rate_review_rounded, color: AppColors.info, size: 20),
            const SizedBox(width: 8),
            Text('Manager Review', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
            const Spacer(),
            if (_task.marks != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Grade: ${_task.marks}${_task.maxMarks != null ? ' / ${_task.maxMarks}' : ''}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
              ),
          ]),
          const SizedBox(height: 12),
          Text(_task.reviewComment!, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: textSecondary, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStudentActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickAndUploadFile,
            icon: _isUploading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.upload_file_rounded, color: AppColors.primary),
            label: Text(_isUploading ? 'Uploading...' : 'Upload File / Photo',
                style: GoogleFonts.plusJakartaSans(color: AppColors.primary, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (!_task.isCompleted) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Submit & Mark Complete',
              onPressed: () async {
                final success = await context.read<TaskProvider>().toggleComplete(_task.id!);
                if (success && mounted) {
                  setState(() => _task = _task.copyWith(
                    isCompleted: true, completedDate: DateTime.now(), status: TaskStatus.completed));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Task submitted successfully!'),
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

  Widget _buildManagerActions() {
    final reviewCtrl = TextEditingController(text: _task.reviewComment ?? '');
    final marksCtrl = TextEditingController(text: _task.marks?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Task', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.textPrimaryDark : AppColors.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: reviewCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add review comment...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          if (_task.maxMarks != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: marksCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Assign Marks (out of ${_task.maxMarks})',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: const Icon(Icons.star_rounded, color: AppColors.primary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Approve',
                  onPressed: () async {
                    int? marks = int.tryParse(marksCtrl.text.trim());
                    await context.read<TaskProvider>().reviewTask(
                      _task.id!, approved: true, comment: reviewCtrl.text.isNotEmpty ? reviewCtrl.text : 'Task approved ✅', marks: marks);
                    if (mounted) {
                      setState(() => _task = _task.copyWith(reviewComment: reviewCtrl.text.isNotEmpty ? reviewCtrl.text : 'Task approved ✅', marks: marks));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Task approved'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                  backgroundColor: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Reject',
                  onPressed: () async {
                    int? marks = int.tryParse(marksCtrl.text.trim());
                    await context.read<TaskProvider>().reviewTask(
                      _task.id!, approved: false, comment: reviewCtrl.text.isNotEmpty ? reviewCtrl.text : 'Task needs revision ❌', marks: marks);
                    if (mounted) {
                      setState(() => _task = _task.copyWith(reviewComment: reviewCtrl.text.isNotEmpty ? reviewCtrl.text : 'Task needs revision ❌', marks: marks));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Task rejected'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    }
                  },
                  backgroundColor: AppColors.error,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleDelete() {
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
              final success = await context.read<TaskProvider>().deleteTask(_task.id!);
              if (success && mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
