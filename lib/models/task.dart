enum TaskStatus { pending, inProgress, completed, overdue }
enum Priority { low, medium, high }

class Task {
  final String? id;
  final String title;
  final String description;
  final DateTime assignedDate;
  final DateTime dueDate;
  final bool isCompleted;
  final DateTime? completedDate;
  final String assignedToUserId;
  final String assignedByUserId;
  final String? submissionPath;
  final String? reviewComment;
  final TaskStatus status;
  final Priority priority;
  final String? category;

  Task({
    this.id,
    required this.title,
    this.description = '',
    required this.assignedDate,
    required this.dueDate,
    this.isCompleted = false,
    this.completedDate,
    required this.assignedToUserId,
    required this.assignedByUserId,
    this.submissionPath,
    this.reviewComment,
    this.status = TaskStatus.pending,
    this.priority = Priority.medium,
    this.category,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'assigned_date': assignedDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'is_completed': isCompleted,
      'completed_date': completedDate?.toIso8601String(),
      'assigned_to_user_id': assignedToUserId,
      'assigned_by_user_id': assignedByUserId,
      'submission_path': submissionPath,
      'review_comment': reviewComment,
      'status': status.name,
      'priority': priority.name,
      'category': category,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      assignedDate: DateTime.tryParse(map['assigned_date'] as String? ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(map['due_date'] as String? ?? '') ?? DateTime.now(),
      isCompleted: map['is_completed'] == true || map['is_completed'] == 1,
      completedDate: map['completed_date'] != null
          ? DateTime.tryParse(map['completed_date'] as String)
          : null,
      assignedToUserId: map['assigned_to_user_id'] as String? ?? '',
      assignedByUserId: map['assigned_by_user_id'] as String? ?? '',
      submissionPath: map['submission_path'] as String?,
      reviewComment: map['review_comment'] as String?,
      status: _parseStatus(map['status'] as String?),
      priority: _parsePriority(map['priority'] as String?),
      category: map['category'] as String?,
    );
  }

  static TaskStatus _parseStatus(String? value) {
    return TaskStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskStatus.pending,
    );
  }

  static Priority _parsePriority(String? value) {
    return Priority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Priority.medium,
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? assignedDate,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? completedDate,
    String? assignedToUserId,
    String? assignedByUserId,
    String? submissionPath,
    String? reviewComment,
    TaskStatus? status,
    Priority? priority,
    String? category,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedDate: assignedDate ?? this.assignedDate,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedByUserId: assignedByUserId ?? this.assignedByUserId,
      submissionPath: submissionPath ?? this.submissionPath,
      reviewComment: reviewComment ?? this.reviewComment,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
    );
  }

  bool get isDueSoon {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inHours;
    return difference >= 0 && difference <= 24 && !isCompleted;
  }

  bool get isOverdue {
    return DateTime.now().isAfter(dueDate) && !isCompleted;
  }

  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }
}
