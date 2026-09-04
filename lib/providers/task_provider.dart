import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/local_storage_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import '../config/supabase_config.dart';

class TaskProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final LocalStorageService _storage = LocalStorageService.instance;

  List<Task> _allTasks = [];
  List<Task> _userTasks = [];
  List<Task> _assignedTasks = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _taskSubscription;

  List<Task> get allTasks => _allTasks;
  List<Task> get userTasks => _userTasks;
  List<Task> get assignedTasks => _assignedTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalTasks => _userTasks.length;
  int get completedTasks => _userTasks.where((t) => t.isCompleted).length;
  int get pendingTasks => _userTasks.where((t) => !t.isCompleted && !t.isOverdue).length;
  int get overdueTasks => _userTasks.where((t) => t.isOverdue).length;

  double get completionRate {
    if (_userTasks.isEmpty) return 0;
    return completedTasks / _userTasks.length;
  }

  List<Task> get todayTasks {
    final now = DateTime.now();
    return _userTasks.where((t) {
      return t.dueDate.year == now.year &&
          t.dueDate.month == now.month &&
          t.dueDate.day == now.day;
    }).toList();
  }

  List<Task> get upcomingTasks {
    final now = DateTime.now();
    return _userTasks
        .where((t) => !t.isCompleted && t.dueDate.isAfter(now))
        .take(5)
        .toList();
  }

  List<Task> get recentCompleted {
    return _userTasks
        .where((t) => t.isCompleted)
        .toList()
      ..sort((a, b) => (b.completedDate ?? b.dueDate).compareTo(a.completedDate ?? a.dueDate));
  }

  Future<void> loadAllTasks() async {
    _isLoading = true;
    notifyListeners();

    // 1. Local Cache
    final localTasks = _storage.getAllTasks();
    if (localTasks.isNotEmpty) {
      _allTasks = localTasks;
      _isLoading = false;
      notifyListeners();
    }

    // 2. Remote Fetch
    try {
      final remoteTasks = await _db.getAllTasks();
      _allTasks = remoteTasks;
      await _storage.saveTasks(remoteTasks);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_allTasks.isEmpty) _error = 'Failed to load tasks (Offline)';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserTasks(String userId) async {
    _isLoading = true;
    notifyListeners();

    // 1. Local Cache
    final localTasks = _storage.getAllTasks();
    if (localTasks.isNotEmpty) {
      _userTasks = localTasks.where((t) => t.assignedUserIds.contains(userId) || t.assignedByUserId == userId).toList();
      _isLoading = false;
      notifyListeners();
    }

    // 2. Remote Fetch
    try {
      final remoteTasks = await _db.getTasksByUser(userId);
      _userTasks = remoteTasks;
      await _storage.saveTasks(remoteTasks);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (_userTasks.isEmpty) _error = 'Failed to load tasks (Offline)';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAssignedTasks(String managerId) async {
    // 1. Local Cache
    final localTasks = _storage.getAllTasks();
    if (localTasks.isNotEmpty) {
      _assignedTasks = localTasks.where((t) => t.assignedByUserId == managerId).toList();
      notifyListeners();
    }

    // 2. Remote Fetch
    try {
      final remoteTasks = await _db.getTasksAssignedBy(managerId);
      _assignedTasks = remoteTasks;
      await _storage.saveTasks(remoteTasks);
      notifyListeners();
    } catch (e) {
      if (_assignedTasks.isEmpty) _error = 'Failed to load assigned tasks (Offline)';
      notifyListeners();
    }
  }

  Future<bool> createTask(Task task) async {
    try {
      final finalTask = task.id == null ? task.copyWith(id: const Uuid().v4()) : task;

      // 1. Save Locally
      await _storage.saveTask(finalTask);
      
      _allTasks.add(finalTask);
      _assignedTasks.add(finalTask);
      if (finalTask.assignedUserIds.isNotEmpty) {
         _userTasks.add(finalTask);
      }
      notifyListeners();

      // 2. Queue for Remote Sync
      await _storage.enqueueSyncAction('CREATE', 'task', finalTask.toMap());
      SyncService.instance.syncNow();
      
      return true;
    } catch (e) {
      _error = 'Failed to create task locally: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTask(Task task) async {
    try {
      // 1. Save Locally
      await _storage.saveTask(task);

      _updateTaskInList(_allTasks, task);
      _updateTaskInList(_userTasks, task);
      _updateTaskInList(_assignedTasks, task);
      notifyListeners();

      // 2. Queue for Remote Sync
      await _storage.enqueueSyncAction('UPDATE', 'task', task.toMap());
      SyncService.instance.syncNow();

      return true;
    } catch (e) {
      _error = 'Failed to update task: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleComplete(String taskId) async {
    try {
      final taskIndex = _userTasks.indexWhere((t) => t.id == taskId);
      final listToUse = taskIndex != -1 ? _userTasks : _allTasks;
      final indexToUse = taskIndex != -1 ? taskIndex : _allTasks.indexWhere((t) => t.id == taskId);
      
      if (indexToUse == -1) return false;
      final task = listToUse[indexToUse];

      final newCompleted = !task.isCompleted;
      final updatedTask = task.copyWith(
        isCompleted: newCompleted,
        completedDate: newCompleted ? DateTime.now() : null,
        status: newCompleted ? TaskStatus.completed : TaskStatus.pending,
      );

      return await updateTask(updatedTask);
    } catch (e) {
      _error = 'Failed to update task';
      notifyListeners();
      return false;
    }
  }

  void _updateTaskInList(List<Task> list, Task updatedTask) {
    final index = list.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      list[index] = updatedTask;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    try {
      // 1. Delete Locally
      await _storage.deleteTask(taskId);
      
      _allTasks.removeWhere((t) => t.id == taskId);
      _userTasks.removeWhere((t) => t.id == taskId);
      _assignedTasks.removeWhere((t) => t.id == taskId);
      notifyListeners();

      // 2. Queue for Remote Sync
      await _storage.enqueueSyncAction('DELETE', 'task', {'id': taskId});
      SyncService.instance.syncNow();

      return true;
    } catch (e) {
      _error = 'Failed to delete task';
      notifyListeners();
      return false;
    }
  }

  Future<bool> reviewTask(String taskId, {required bool approved, String? comment, int? marks}) async {
    try {
      final taskIndex = _allTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex == -1) return false;

      final task = _allTasks[taskIndex];
      final updatedTask = task.copyWith(
        reviewComment: comment,
        marks: marks,
        isCompleted: approved ? task.isCompleted : false,
        status: approved ? task.status : TaskStatus.inProgress,
      );

      return await updateTask(updatedTask);
    } catch (e) {
      _error = 'Failed to review task';
      notifyListeners();
      return false;
    }
  }

  List<Task> getTasksForStudent(String studentId) {
    return _allTasks.where((t) => t.assignedUserIds.contains(studentId)).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void initRealtime(String userId, bool isManager) {
    _taskSubscription?.cancel();
    _taskSubscription = SupabaseConfig.client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .listen((_) {
      if (isManager) {
        loadAllTasks();
        loadAssignedTasks(userId);
      } else {
        final oldTaskIds = _userTasks.map((t) => t.id).toSet();
        
        loadUserTasks(userId).then((_) {
          if (oldTaskIds.isNotEmpty) {
            final newTaskIds = _userTasks.map((t) => t.id).toSet();
            final newlyAdded = newTaskIds.difference(oldTaskIds);
            for (final id in newlyAdded) {
              final task = _userTasks.firstWhere((t) => t.id == id);
              NotificationService.instance.notifyTaskAssigned(task.title);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    super.dispose();
  }
}
