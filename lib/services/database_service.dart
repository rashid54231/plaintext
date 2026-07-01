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
      await _supabase
          .from('users')
          .insert(user.toMap());
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

      return response['id'] as String?;
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

      return (response as List).map((map) => Task.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Task>> getTasksByUser(String userId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('assigned_to_user_id', userId)
          .order('due_date', ascending: true);

      return (response as List).map((map) => Task.fromMap(map)).toList();
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

      return (response as List).map((map) => Task.fromMap(map)).toList();
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
      return Task.fromMap(response);
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
      await _supabase
          .from('tasks')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete task: $e');
    }
  }

  Future<Map<String, int>> getTaskCountByUser(String userId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select('id, is_completed, due_date')
          .eq('assigned_to_user_id', userId);

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
}
