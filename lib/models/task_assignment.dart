import 'dart:convert';

class TaskAssignment {
  final String? id;
  final String taskId;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userAvatarUrl;
  final List<String> submissionPaths;
  final DateTime? submittedAt;
  final int? marks;
  final String? reviewComment;
  final DateTime? reviewedAt;
  final bool isCompleted;
  final DateTime? completedDate;
  final String status; // 'pending', 'inProgress', 'submitted', 'completed', 'rejected'
  final DateTime assignedAt;

  TaskAssignment({
    this.id,
    required this.taskId,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userAvatarUrl,
    this.submissionPaths = const [],
    this.submittedAt,
    this.marks,
    this.reviewComment,
    this.reviewedAt,
    this.isCompleted = false,
    this.completedDate,
    this.status = 'pending',
    DateTime? assignedAt,
  }) : assignedAt = assignedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'task_id': taskId,
      'user_id': userId,
      'submission_paths': submissionPaths.isNotEmpty ? jsonEncode(submissionPaths) : null,
      'submitted_at': submittedAt?.toIso8601String(),
      'marks': marks,
      'review_comment': reviewComment,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'is_completed': isCompleted,
      'completed_date': completedDate?.toIso8601String(),
      'status': status,
      'assigned_at': assignedAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TaskAssignment.fromMap(Map<String, dynamic> map, {
    String? userName,
    String? userEmail,
    String? userAvatarUrl,
  }) {
    List<String> paths = [];
    final rawPaths = map['submission_paths'] ?? map['submission_path'];
    if (rawPaths != null) {
      if (rawPaths is List) {
        paths = List<String>.from(rawPaths);
      } else if (rawPaths is String && rawPaths.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawPaths);
          if (decoded is List) {
            paths = List<String>.from(decoded);
          } else {
            paths = [rawPaths];
          }
        } catch (_) {
          paths = [rawPaths];
        }
      }
    }

    final userObj = map['users'];
    String? uName = userName;
    String? uEmail = userEmail;
    String? uAvatar = userAvatarUrl;

    if (userObj is Map<String, dynamic>) {
      uName = userObj['name'] as String? ?? uName;
      uEmail = userObj['email'] as String? ?? uEmail;
      uAvatar = userObj['avatar_url'] as String? ?? uAvatar;
    }

    return TaskAssignment(
      id: map['id'] as String?,
      taskId: map['task_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      userName: uName,
      userEmail: uEmail,
      userAvatarUrl: uAvatar,
      submissionPaths: paths,
      submittedAt: map['submitted_at'] != null ? DateTime.tryParse(map['submitted_at'] as String) : null,
      marks: map['marks'] as int?,
      reviewComment: map['review_comment'] as String?,
      reviewedAt: map['reviewed_at'] != null ? DateTime.tryParse(map['reviewed_at'] as String) : null,
      isCompleted: map['is_completed'] == true || map['is_completed'] == 1,
      completedDate: map['completed_date'] != null ? DateTime.tryParse(map['completed_date'] as String) : null,
      status: map['status'] as String? ?? 'pending',
      assignedAt: map['assigned_at'] != null
          ? DateTime.tryParse(map['assigned_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  TaskAssignment copyWith({
    String? id,
    String? taskId,
    String? userId,
    String? userName,
    String? userEmail,
    String? userAvatarUrl,
    List<String>? submissionPaths,
    DateTime? submittedAt,
    int? marks,
    String? reviewComment,
    DateTime? reviewedAt,
    bool? isCompleted,
    DateTime? completedDate,
    String? status,
    DateTime? assignedAt,
  }) {
    return TaskAssignment(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      submissionPaths: submissionPaths ?? this.submissionPaths,
      submittedAt: submittedAt ?? this.submittedAt,
      marks: marks ?? this.marks,
      reviewComment: reviewComment ?? this.reviewComment,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }
}
