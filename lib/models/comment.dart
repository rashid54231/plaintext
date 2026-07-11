class TaskComment {
  final String? id;
  final String taskId;
  final String userId;
  final String userName;
  final String userRole;
  final String message;
  final DateTime createdAt;

  TaskComment({
    this.id,
    required this.taskId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.message,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'task_id': taskId,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory TaskComment.fromMap(Map<String, dynamic> map) {
    return TaskComment(
      id: map['id'] as String?,
      taskId: map['task_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      userName: map['user_name'] as String? ?? '',
      userRole: map['user_role'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  bool get isManager => userRole == 'manager';
}
