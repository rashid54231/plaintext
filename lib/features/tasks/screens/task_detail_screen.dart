import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task.dart';
import '../../../models/user.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/database_service.dart';
import '../../../services/file_picker_service.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/status_badge.dart';
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
      final updatedTask = _task.copyWith(submissionPath: _uploadedFiles.first);
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
        title: const Text('Task Detail'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Comments button
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
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
                    child: Text('$_commentCount', style: GoogleFonts.inter(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          if (isManager) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CreateTaskScreen(editTask: _task)));
                final updated = await DatabaseService.instance.getTaskById(_task.id!);
                if (updated != null && mounted) setState(() => _task = updated);
              },
            ),
            IconButton(icon: const Icon(Icons.delete_rounded), onPressed: _handleDelete),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildInfoSection(card, textPrimary, textHint),
            const SizedBox(height: 16),
            _buildDescriptionSection(card, textPrimary, textSecondary),
            const SizedBox(height: 16),
            _buildDatesSection(card, textHint),
            const SizedBox(height: 16),
            _buildSubmissionSection(isManager, card, textPrimary, textHint),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_priorityColor, _priorityColor.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _priorityColor.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
                child: Text(_task.priority.name.toUpperCase(),
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const Spacer(),
              StatusBadge(
                text: _task.isCompleted ? 'Completed' : (_task.isOverdue ? 'Overdue' : 'Active'),
                backgroundColor: Colors.white24,
                textColor: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(_task.title,
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          if (_task.category != null && _task.category!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Text(_task.category!,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
            ),
          ],
        ],
      ),
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
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: textHint)),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary)),
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
            Text('Description', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
          ]),
          const SizedBox(height: 12),
          Text(
            _task.description.isNotEmpty ? _task.description : 'No description provided',
            style: GoogleFonts.inter(
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
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint)),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ],
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
              Icon(Icons.attach_file_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Submissions', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
              const Spacer(),
              if (_uploadedFiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_uploadedFiles.length}',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingFiles)
            const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          else if (_uploadedFiles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 36, color: textHint),
                  const SizedBox(height: 8),
                  Text('No files submitted yet', style: GoogleFonts.inter(fontSize: 13, color: textHint)),
                ],
              ),
            )
          else
            ...List.generate(_uploadedFiles.length, (i) {
              final url = _uploadedFiles[i];
              final isImage = ['.jpg', '.jpeg', '.png', '.gif', '.webp']
                  .any((ext) => url.toLowerCase().contains(ext));
              final fileName = url.split('/').last.split('?').first;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isImage
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded,
                        color: isImage ? AppColors.success : AppColors.info,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName.length > 30 ? '${fileName.substring(0, 30)}...' : fileName,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 22),
                      onPressed: () => _downloadFile(url),
                    ),
                  ],
                ),
              );
            }),
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
            Text('Manager Review', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
            const Spacer(),
            if (_task.marks != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Grade: ${_task.marks}${_task.maxMarks != null ? ' / ${_task.maxMarks}' : ''}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
              ),
          ]),
          const SizedBox(height: 12),
          Text(_task.reviewComment!, style: GoogleFonts.inter(fontSize: 14, color: textSecondary, height: 1.5)),
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
                style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
          Text('Review Task', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600,
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
        title: Text('Delete Task', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Delete "${_task.title}"?', style: GoogleFonts.inter()),
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
