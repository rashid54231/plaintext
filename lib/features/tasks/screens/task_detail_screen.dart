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

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await FilePickerService.instance.getTaskFiles(_task.id!);
    if (mounted) {
      setState(() {
        _uploadedFiles = files;
        _isLoadingFiles = false;
      });
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final filePicker = FilePickerService.instance;
      final result = await filePicker.pickFiles(
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);

      final urls = await filePicker.uploadMultipleFiles(
        taskId: _task.id!,
        files: result.files,
      );

      _uploadedFiles.addAll(urls);

      // Update task with submission path
      final updatedTask = _task.copyWith(
        submissionPath: _uploadedFiles.first,
      );
      await context.read<TaskProvider>().updateTask(updatedTask);

      setState(() {
        _task = updatedTask;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.files.length} file(s) uploaded successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isManager = userProvider.isManager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Detail'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (isManager)
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed: _handleDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildInfoSection(),
            const SizedBox(height: 24),
            _buildDescriptionSection(),
            const SizedBox(height: 24),
            _buildDatesSection(),
            const SizedBox(height: 24),
            _buildSubmissionSection(isManager),
            if (_task.reviewComment != null && _task.reviewComment!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildReviewSection(),
            ],
            const SizedBox(height: 32),
            if (!isManager && !_task.isCompleted) _buildStudentActions(),
            if (isManager && !_task.isCompleted) _buildManagerActions(),
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
          colors: [
            _getPriorityColor(_task.priority),
            _getPriorityColor(_task.priority).withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getPriorityColor(_task.priority).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _task.priority.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              if (_task.isCompleted)
                const StatusBadge(
                  text: 'Completed',
                  backgroundColor: Colors.white24,
                  textColor: Colors.white,
                )
              else if (_task.isOverdue)
                const StatusBadge(
                  text: 'Overdue',
                  backgroundColor: Colors.white24,
                  textColor: Colors.white,
                )
              else
                const StatusBadge(
                  text: 'Active',
                  backgroundColor: Colors.white24,
                  textColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _task.title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_task.category != null && _task.category!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _task.category!,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return FutureBuilder<List<User>>(
      future: DatabaseService.instance.getTaskAssignedUsers(_task.id!),
      builder: (context, assignedSnapshot) {
        return FutureBuilder<User?>(
          future: DatabaseService.instance.getUserById(_task.assignedByUserId),
          builder: (context, managerSnapshot) {
            final assignedUsers = assignedSnapshot.data ?? [];
            final assignedBy = managerSnapshot.data;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.people_rounded,
                    'Assigned To (${assignedUsers.length})',
                    assignedUsers.map((u) => u.name).join(', '),
                    AppColors.info,
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    Icons.admin_panel_settings_rounded,
                    'Assigned By',
                    assignedBy?.name ?? 'Loading...',
                    AppColors.primary,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Description', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _task.description.isNotEmpty ? _task.description : 'No description provided',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _task.description.isNotEmpty ? AppColors.textSecondary : AppColors.textHint,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _buildDateRow(Icons.assignment_rounded, 'Assigned Date', DateFormatter.formatDateTime(_task.assignedDate), AppColors.info),
          const Divider(height: 24),
          _buildDateRow(Icons.event_rounded, 'Due Date', DateFormatter.formatDateTime(_task.dueDate), _task.isOverdue ? AppColors.error : AppColors.warning),
          if (_task.completedDate != null) ...[
            const Divider(height: 24),
            _buildDateRow(Icons.check_circle_rounded, 'Completed On', DateFormatter.formatDateTime(_task.completedDate!), AppColors.success),
          ],
          const Divider(height: 24),
          _buildDateRow(
            Icons.schedule_rounded,
            _task.isOverdue ? 'Overdue By' : 'Days Until Due',
            _task.isOverdue
                ? '${-_task.daysUntilDue} day${-_task.daysUntilDue != 1 ? 's' : ''}'
                : _task.daysUntilDue == 0 ? 'Due today' : '${_task.daysUntilDue} day${_task.daysUntilDue != 1 ? 's' : ''}',
            _task.isOverdue ? AppColors.error : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
              Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // SUBMISSION SECTION - File Upload & View
  // ============================================
  Widget _buildSubmissionSection(bool isManager) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Submissions',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const Spacer(),
              if (_uploadedFiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_uploadedFiles.length}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingFiles)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_uploadedFiles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 40, color: AppColors.textHint),
                  const SizedBox(height: 8),
                  Text(
                    'No files submitted yet',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textHint),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_uploadedFiles.length, (index) {
              final url = _uploadedFiles[index];
              final isImage = url.toLowerCase().endsWith('.jpg') ||
                  url.toLowerCase().endsWith('.jpeg') ||
                  url.toLowerCase().endsWith('.png') ||
                  url.toLowerCase().endsWith('.gif') ||
                  url.toLowerCase().endsWith('.webp');
              final fileName = url.split('/').last.split('?').first;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isImage ? AppColors.success.withValues(alpha: 0.1) : AppColors.info.withValues(alpha: 0.1),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName.length > 30 ? '${fileName.substring(0, 30)}...' : fileName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isManager ? 'Student submission' : 'Your submission',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 22),
                      onPressed: () => _downloadFile(url),
                      tooltip: 'Download',
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rate_review_rounded, color: AppColors.info, size: 20),
              const SizedBox(width: 8),
              Text('Manager Review', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_task.reviewComment!, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }

  // ============================================
  // STUDENT ACTIONS - Upload & Complete
  // ============================================
  Widget _buildStudentActions() {
    return Column(
      children: [
        // Upload File Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isUploading ? null : _pickAndUploadFile,
            icon: _isUploading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.upload_file_rounded, color: AppColors.primary),
            label: Text(
              _isUploading ? 'Uploading...' : 'Upload File / Photo',
              style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Mark Complete Button
        SizedBox(
          width: double.infinity,
          child: CustomButton(
            text: 'Submit & Mark Complete',
            isLoading: false,
            onPressed: () async {
              final success = await context.read<TaskProvider>().toggleComplete(_task.id!);
              if (success && mounted) {
                setState(() {
                  _task = _task.copyWith(
                    isCompleted: true,
                    completedDate: DateTime.now(),
                    status: TaskStatus.completed,
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Task submitted successfully!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            backgroundColor: AppColors.success,
            icon: Icons.send_rounded,
          ),
        ),
      ],
    );
  }

  // ============================================
  // MANAGER ACTIONS - Approve / Reject
  // ============================================
  Widget _buildManagerActions() {
    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Approve',
            onPressed: () async {
              await context.read<TaskProvider>().reviewTask(_task.id!, approved: true, comment: 'Task approved');
              if (mounted) {
                setState(() => _task = _task.copyWith(reviewComment: 'Task approved'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Task approved'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            backgroundColor: AppColors.success,
            icon: Icons.approval_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomButton(
            text: 'Reject',
            onPressed: () async {
              await context.read<TaskProvider>().reviewTask(_task.id!, approved: false, comment: 'Task needs revision');
              if (mounted) {
                setState(() => _task = _task.copyWith(reviewComment: 'Task needs revision'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Task rejected'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            backgroundColor: AppColors.error,
            icon: Icons.cancel_rounded,
          ),
        ),
      ],
    );
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Task', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete "${_task.title}"?', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await FilePickerService.instance.deleteTaskFiles(_task.id!);
              final success = await context.read<TaskProvider>().deleteTask(_task.id!);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Task deleted'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return AppColors.highPriority;
      case Priority.medium:
        return AppColors.mediumPriority;
      case Priority.low:
        return AppColors.lowPriority;
    }
  }
}
