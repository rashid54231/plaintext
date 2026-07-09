import '../config/supabase_config.dart';
import '../models/user.dart';
import '../models/task.dart';

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

      return response.isNotEmpty;
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

  Future<void> insertUser(User user) async {
    try {
      await _supabase.from('users').insert(user.toMap());
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
          .order('created_at', ascending: false);

      return (response as List).map((map) => User.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateUser(User user) async {
    try {
      await _supabase
          .from('users')
          .update(user.toMap())
          .eq('id', user.id!);
    } catch (e) {
      throw Exception('Failed to update user: $e');
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

      // Insert assignments
      if (taskId != null && task.assignedUserIds.isNotEmpty) {
        await assignTaskToStudents(taskId, task.assignedUserIds);
      }

      return taskId;
    } catch (e) {
      throw Exception('Failed to create task: $e');
    }
  }

  Future<List<Task>> getAllTasks() async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .order('due_date', ascending: true);

      final tasks = <Task>[];
      for (final map in response as List) {
        final task = Task.fromMap(map);
        final assignedIds = await getTaskAssignedUserIds(task.id!);
        tasks.add(task.copyWith(assignedUserIds: assignedIds));
      }
      return tasks;
    } catch (e) {
      return [];
    }
  }

  Future<List<Task>> getTasksByUser(String userId) async {
    try {
      // Get task IDs assigned to this user
      final assignments = await _supabase
          .from('task_assignments')
          .select('task_id')
          .eq('user_id', userId);

      final taskIds = (assignments as List).map((a) => a['task_id'] as String).toList();

      if (taskIds.isEmpty) return [];

      final response = await _supabase
          .from('tasks')
          .select()
          .inFilter('id', taskIds)
          .order('due_date', ascending: true);

      final tasks = <Task>[];
      for (final map in response as List) {
        final task = Task.fromMap(map);
        final assignedIds = await getTaskAssignedUserIds(task.id!);
        tasks.add(task.copyWith(assignedUserIds: assignedIds));
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

      final tasks = <Task>[];
      for (final map in response as List) {
        final task = Task.fromMap(map);
        final assignedIds = await getTaskAssignedUserIds(task.id!);
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
      await _supabase
          .from('tasks')
          .update(task.toMap())
          .eq('id', task.id!);
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
          .select('task_id')
          .eq('user_id', userId);

      final taskIds = (assignments as List).map((a) => a['task_id'] as String).toList();

      if (taskIds.isEmpty) {
        return {'total': 0, 'completed': 0, 'pending': 0, 'overdue': 0};
      }

      final response = await _supabase
          .from('tasks')
          .select('id, is_completed, due_date')
          .inFilter('id', taskIds);

      final tasks = response as List;
      final now = DateTime.now();

      int total = tasks.length;
      int completed = tasks.where((t) => t['is_completed'] == true).length;
      int pending = tasks.where((t) =>
          t['is_completed'] == false &&
          DateTime.parse(t['due_date']).isAfter(now)).length;
      int overdue = tasks.where((t) =>
          t['is_completed'] == false &&
          DateTime.parse(t['due_date']).isBefore(now)).length;

      return {'total': total, 'completed': completed, 'pending': pending, 'overdue': overdue};
    } catch (e) {
      return {'total': 0, 'completed': 0, 'pending': 0, 'overdue': 0};
    }
  }

  // ============================================
  // TASK ASSIGNMENTS (Many-to-Many)
  // ============================================

  Future<void> assignTaskToStudents(String taskId, List<String> userIds) async {
    try {
      final assignments = userIds.map((userId) => {
        'task_id': taskId,
        'user_id': userId,
      }).toList();

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

  Future<void> updateTaskAssignments(String taskId, List<String> userIds) async {
    try {
      // Remove old assignments
      await removeTaskAssignments(taskId);
      // Add new assignments
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

      final users = <User>[];
      for (final userId in userIds) {
        final user = await getUserById(userId);
        if (user != null) users.add(user);
      }
      return users;
    } catch (e) {
      return [];
    }
  }

  Future<bool> isTaskAssignedToUser(String taskId, String userId) async {
    try {
      final response = await _supabase
          .from('task_assignments')
          .select('id')
          .eq('task_id', taskId)
          .eq('user_id', userId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
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
}
