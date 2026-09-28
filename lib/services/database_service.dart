import 'dart:convert';
import '../config/supabase_config.dart';
import '../models/user.dart';
import '../models/task.dart';
import '../models/task_assignment.dart';
import '../models/comment.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  final _supabase = SupabaseConfig.client;

  // ============================================
  // USER OPERATIONS
  // ============================================

  Future<User?> getUserByEmail(String email) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();
      if (response == null) return null;
      return User.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<User?> getUserById(String id) async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      return User.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasManager() async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('role', 'manager')
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<String?> insertUserAndGetId(User user) async {
    try {
      final response = await _supabase
          .from('users')
          .insert(user.toMap())
          .select('id')
          .single();
      return response['id'] as String?;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<List<User>> getAllStudents() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('role', 'student')
          .order('name', ascending: true);
      return (response as List).map((map) => User.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateUser(User user) async {
    try {
      final payload = user.toMap();
      payload.remove('id');
      payload.remove('created_at');
      
      final response = await _supabase
          .from('users')
          .update(payload)
          .eq('id', user.id!)
          .select();
          
      if (response.isEmpty) {
        throw Exception('User not found or update failed silently.');
      }
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> updateUserAvatar(String userId, String avatarUrl) async {
    try {
      await _supabase.from('users').update({'avatar_url': avatarUrl}).eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update avatar: $e');
    }
  }

  Future<void> updateUserPassword(String email, String newPassword) async {
    try {
      final response = await _supabase
          .from('users')
          .update({'password': newPassword})
          .eq('email', email.trim().toLowerCase())
          .select();
      if (response.isEmpty) {
        throw Exception('User not found or password update failed.');
      }
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  // ============================================
  // TASK OPERATIONS
  // ============================================

  Future<String?> insertTask(Task task) async {
    try {
      final response = await _supabase
          .from('tasks')
          .insert(task.toMap())
          .select('id')
          .single();
      final taskId = response['id'] as String?;
      if (taskId != null && task.assignedUserIds.isNotEmpty) {
        await assignTaskToStudents(taskId, task.assignedUserIds);
      }
      return taskId;
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<Map<String, List<String>>> _getBulkTaskAssignments(List<String> taskIds) async {
    if (taskIds.isEmpty) return {};
    try {
      final response = await _supabase
          .from('task_assignments')
          .select('task_id, user_id')
          .inFilter('task_id', taskIds);
      final map = <String, List<String>>{};
      for (final a in response as List) {
        final tid = a['task_id'] as String;
        final uid = a['user_id'] as String;
        map.putIfAbsent(tid, () => []).add(uid);
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  Future<List<Task>> getAllTasks() async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .order('due_date', ascending: true);
      final rawList = response as List;
      final taskIds = rawList.map((m) => m['id'] as String).toList();
      final assignmentsMap = await _getBulkTaskAssignments(taskIds);

      final tasks = <Task>[];
      for (final map in rawList) {
        final task = Task.fromMap(map);
        final assignedIds = assignmentsMap[task.id] ?? [];
        tasks.add(task.copyWith(assignedUserIds: assignedIds));
      }
      return tasks;
    } catch (e) {
      return [];
    }
  }

  Future<List<Task>> searchTasks(String query, {String? role, String? userId}) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .ilike('title', '%$query%')
          .order('due_date', ascending: true);
      final rawList = response as List;
      final taskIds = rawList.map((m) => m['id'] as String).toList();
      final assignmentsMap = await _getBulkTaskAssignments(taskIds);

      final tasks = <Task>[];
      for (final map in rawList) {
        final task = Task.fromMap(map);
        final assignedIds = assignmentsMap[task.id] ?? [];
        if (role == 'student' && userId != null) {
          if (!assignedIds.contains(userId)) continue;
        }
        tasks.add(task.copyWith(assignedUserIds: assignedIds));
      }
      return tasks;
    } catch (e) {
      return [];
    }
  }

  Future<List<Task>> getTasksByUser(String userId) async {
    try {
      final assignments = await _supabase
          .from('task_assignments')
          .select()
          .eq('user_id', userId);
      final rawAssignments = assignments as List;
      final taskIds =
          rawAssignments.map((a) => a['task_id'] as String).toList();
      if (taskIds.isEmpty) return [];

      final response = await _supabase
          .from('tasks')
          .select()
          .inFilter('id', taskIds)
          .order('due_date', ascending: true);

      final rawList = response as List;
      final assignmentsMap = await _getBulkTaskAssignments(taskIds);

      final userAssignmentMap = <String, Map<String, dynamic>>{};
      for (final a in rawAssignments) {
        userAssignmentMap[a['task_id'] as String] = a;
      }

      final tasks = <Task>[];
      for (final map in rawList) {
        final task = Task.fromMap(map);
        final assignedIds = assignmentsMap[task.id] ?? [];
        
        final personal = userAssignmentMap[task.id];
        if (personal != null) {
          final isComp = personal['is_completed'] == true || personal['is_completed'] == 1;
          final compDate = personal['completed_date'] != null 
              ? DateTime.tryParse(personal['completed_date'] as String) 
              : null;
          
          List<String> subPaths = [];
          final rawPaths = personal['submission_paths'] ?? personal['submission_path'];
          if (rawPaths != null) {
            if (rawPaths is List) {
              subPaths = List<String>.from(rawPaths);
            } else if (rawPaths is String && rawPaths.trim().isNotEmpty) {
              try {
                final decoded = jsonDecode(rawPaths);
                if (decoded is List) {
                  subPaths = List<String>.from(decoded);
                } else {
                  subPaths = [rawPaths];
                }
              } catch (_) {
                subPaths = [rawPaths];
              }
            }
          }

          final marks = personal['marks'] as int?;
          final reviewComment = personal['review_comment'] as String?;
          final statusStr = personal['status'] as String?;
          final personalStatus = statusStr != null 
              ? TaskStatus.values.firstWhere((e) => e.name == statusStr, orElse: () => task.status)
              : task.status;

          tasks.add(task.copyWith(
            assignedUserIds: assignedIds,
            isCompleted: isComp,
            completedDate: compDate,
            submissionPaths: subPaths.isNotEmpty ? subPaths : task.submissionPaths,
            marks: marks ?? task.marks,
            reviewComment: reviewComment ?? task.reviewComment,
            status: isComp ? TaskStatus.completed : personalStatus,
          ));
        } else {
          tasks.add(task.copyWith(assignedUserIds: assignedIds));
        }
      }
      return tasks;
    } catch (e) {
      return [];
    }
  }

  Future<List<Task>> getTasksAssignedBy(String userId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('assigned_by_user_id', userId)
          .order('due_date', ascending: true);
      final rawList = response as List;
      final taskIds = rawList.map((m) => m['id'] as String).toList();
      final assignmentsMap = await _getBulkTaskAssignments(taskIds);

      final tasks = <Task>[];
      for (final map in rawList) {
        final task = Task.fromMap(map);
        final assignedIds = assignmentsMap[task.id] ?? [];
        tasks.add(task.copyWith(assignedUserIds: assignedIds));
      }
      return tasks;
    } catch (e) {
      return [];
    }
  }

  Future<Task?> getTaskById(String id) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (response == null) return null;
      final task = Task.fromMap(response);
      final assignedIds = await getTaskAssignedUserIds(task.id!);
      return task.copyWith(assignedUserIds: assignedIds);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      await _supabase.from('tasks').update(task.toMap()).eq('id', task.id!);
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _supabase.from('tasks').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete task: $e');
    }
  }

  Future<Map<String, int>> getTaskCountByUser(String userId) async {
    try {
      final assignments = await _supabase
          .from('task_assignments')
          .select('task_id, is_completed, status')
          .eq('user_id', userId);
      final assignmentList = assignments as List;
      if (assignmentList.isEmpty) {
        return {'total': 0, 'completed': 0, 'pending': 0, 'overdue': 0};
      }
      
      final taskIds = assignmentList.map((a) => a['task_id'] as String).toList();
      final tasksResp = await _supabase
          .from('tasks')
          .select('id, due_date')
          .inFilter('id', taskIds);
      
      final tasksMap = <String, dynamic>{};
      for (final t in tasksResp as List) {
        tasksMap[t['id'] as String] = t;
      }

      final now = DateTime.now();
      int total = assignmentList.length;
      int completed = 0;
      int pending = 0;
      int overdue = 0;

      for (final a in assignmentList) {
        final isComp = a['is_completed'] == true || a['is_completed'] == 1;
        if (isComp) {
          completed++;
        } else {
          final t = tasksMap[a['task_id']];
          final dueDate = t != null ? DateTime.tryParse(t['due_date'] ?? '') : null;
          if (dueDate != null && dueDate.isBefore(now)) {
            overdue++;
          } else {
            pending++;
          }
        }
      }

      return {
        'total': total,
        'completed': completed,
        'pending': pending,
        'overdue': overdue,
      };
    } catch (e) {
      return {'total': 0, 'completed': 0, 'pending': 0, 'overdue': 0};
    }
  }

  Future<int> getTotalMarksByUser(String userId) async {
    try {
      final response = await _supabase
          .from('task_assignments')
          .select('marks')
          .eq('user_id', userId);
      final list = response as List;
      int totalMarks = 0;
      for (var item in list) {
        if (item['marks'] != null) {
          totalMarks += (item['marks'] as int);
        }
      }
      return totalMarks;
    } catch (e) {
      return 0;
    }
  }

  Future<List<TaskAssignment>> getTaskAssignments(String taskId) async {
    try {
      final response = await _supabase
          .from('task_assignments')
          .select()
          .eq('task_id', taskId);
      final rawList = response as List;
      if (rawList.isEmpty) return [];

      final userIds = rawList.map((m) => m['user_id'] as String).toList();
      final usersResponse = await _supabase
          .from('users')
          .select('id, name, email, avatar_url')
          .inFilter('id', userIds);

      final usersMap = <String, Map<String, dynamic>>{};
      for (final u in usersResponse as List) {
        usersMap[u['id'] as String] = u;
      }

      return rawList.map((m) {
        final uid = m['user_id'] as String;
        final u = usersMap[uid];
        return TaskAssignment.fromMap(
          m,
          userName: u?['name'] as String?,
          userEmail: u?['email'] as String?,
          userAvatarUrl: u?['avatar_url'] as String?,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<TaskAssignment?> getStudentAssignment(String taskId, String userId) async {
    try {
      final response = await _supabase
          .from('task_assignments')
          .select()
          .eq('task_id', taskId)
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      final user = await getUserById(userId);
      return TaskAssignment.fromMap(
        response,
        userName: user?.name,
        userEmail: user?.email,
        userAvatarUrl: user?.avatarUrl,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> submitStudentAssignment({
    required String taskId,
    required String userId,
    required List<String> submissionPaths,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final payload = {
        'submission_paths': jsonEncode(submissionPaths),
        'submitted_at': now,
        'status': 'submitted',
        'is_completed': true,
        'completed_date': now,
      };

      await _supabase
          .from('task_assignments')
          .update(payload)
          .eq('task_id', taskId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to submit assignment: $e');
    }
  }

  Future<void> gradeStudentAssignment({
    required String taskId,
    required String userId,
    required int? marks,
    required String? reviewComment,
    required bool approved,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final payload = {
        'marks': marks,
        'review_comment': reviewComment,
        'reviewed_at': now,
        'status': approved ? 'completed' : 'rejected',
        'is_completed': approved,
      };

      await _supabase
          .from('task_assignments')
          .update(payload)
          .eq('task_id', taskId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to grade assignment: $e');
    }
  }

  // ============================================
  // TASK ASSIGNMENTS (Many-to-Many)
  // ============================================

  Future<void> assignTaskToStudents(String taskId, List<String> userIds) async {
    try {
      final assignments = userIds
          .map((userId) => {'task_id': taskId, 'user_id': userId})
          .toList();
      await _supabase.from('task_assignments').insert(assignments);
    } catch (e) {
      throw Exception('Failed to assign task: $e');
    }
  }

  Future<void> removeTaskAssignments(String taskId) async {
    try {
      await _supabase
          .from('task_assignments')
          .delete()
          .eq('task_id', taskId);
    } catch (e) {
      throw Exception('Failed to remove assignments: $e');
    }
  }

  Future<void> updateTaskAssignments(
      String taskId, List<String> userIds) async {
    try {
      await removeTaskAssignments(taskId);
      if (userIds.isNotEmpty) {
        await assignTaskToStudents(taskId, userIds);
      }
    } catch (e) {
      throw Exception('Failed to update assignments: $e');
    }
  }

  Future<List<String>> getTaskAssignedUserIds(String taskId) async {
    try {
      final response = await _supabase
          .from('task_assignments')
          .select('user_id')
          .eq('task_id', taskId);
      return (response as List).map((a) => a['user_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<User>> getTaskAssignedUsers(String taskId) async {
    try {
      final userIds = await getTaskAssignedUserIds(taskId);
      if (userIds.isEmpty) return [];
      final response = await _supabase
          .from('users')
          .select()
          .inFilter('id', userIds);
      return (response as List).map((m) => User.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<User>> getStudentsNotAssignedToTask(String taskId) async {
    try {
      final assignedIds = await getTaskAssignedUserIds(taskId);
      final allStudents = await getAllStudents();
      if (assignedIds.isEmpty) return allStudents;
      return allStudents.where((s) => !assignedIds.contains(s.id)).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================
  // COMMENTS
  // ============================================

  Future<List<TaskComment>> getComments(String taskId) async {
    try {
      final response = await _supabase
          .from('task_comments')
          .select()
          .eq('task_id', taskId)
          .order('created_at', ascending: true);
      return (response as List)
          .map((map) => TaskComment.fromMap(map))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<TaskComment?> addComment(TaskComment comment) async {
    try {
      final response = await _supabase
          .from('task_comments')
          .insert(comment.toMap())
          .select()
          .single();
      return TaskComment.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _supabase
          .from('task_comments')
          .delete()
          .eq('id', commentId);
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }
}
