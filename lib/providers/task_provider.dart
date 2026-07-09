import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';

class TaskProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<Task> _allTasks = [];
  List<Task> _userTasks = [];
  List<Task> _assignedTasks = [];
  bool _isLoading = false;
  String? _error;

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

    try {
      _allTasks = await _db.getAllTasks();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load tasks';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserTasks(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userTasks = await _db.getTasksByUser(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load tasks';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAssignedTasks(String managerId) async {
    try {
      _assignedTasks = await _db.getTasksAssignedBy(managerId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load assigned tasks';
      notifyListeners();
    }
  }

  Future<bool> createTask(Task task) async {
    _isLoading = true;
    notifyListeners();

    try {
      final id = await _db.insertTask(task);
      final newTask = task.copyWith(id: id);
      _allTasks.add(newTask);
      _assignedTasks.add(newTask);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to create task: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTask(Task task) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _db.updateTask(task);

      _updateTaskInList(_allTasks, task);
      _updateTaskInList(_userTasks, task);
      _updateTaskInList(_assignedTasks, task);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update task: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleComplete(String taskId) async {
    try {
      final taskIndex = _userTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex == -1) {
        final allIndex = _allTasks.indexWhere((t) => t.id == taskId);
        if (allIndex == -1) return false;
      }

      final list = taskIndex != -1 ? _userTasks : _allTasks;
      final index = taskIndex != -1 ? taskIndex : _allTasks.indexWhere((t) => t.id == taskId);
      final task = list[index];

      final newCompleted = !task.isCompleted;
      final updatedTask = task.copyWith(
        isCompleted: newCompleted,
        completedDate: newCompleted ? DateTime.now() : null,
        status: newCompleted ? TaskStatus.completed : TaskStatus.pending,
      );

      await _db.updateTask(updatedTask);

      _updateTaskInList(_allTasks, updatedTask);
      _updateTaskInList(_userTasks, updatedTask);
      _updateTaskInList(_assignedTasks, updatedTask);

      notifyListeners();
      return true;
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
    _isLoading = true;
    notifyListeners();

    try {
      await _db.deleteTask(taskId);
      _allTasks.removeWhere((t) => t.id == taskId);
      _userTasks.removeWhere((t) => t.id == taskId);
      _assignedTasks.removeWhere((t) => t.id == taskId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete task';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> reviewTask(String taskId, {required bool approved, String? comment}) async {
    try {
      final taskIndex = _allTasks.indexWhere((t) => t.id == taskId);
      if (taskIndex == -1) return false;

      final task = _allTasks[taskIndex];
      final updatedTask = task.copyWith(
        reviewComment: comment,
      );

      await _db.updateTask(updatedTask);

      _updateTaskInList(_allTasks, updatedTask);
      _updateTaskInList(_userTasks, updatedTask);
      _updateTaskInList(_assignedTasks, updatedTask);

      notifyListeners();
      return true;
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
}
