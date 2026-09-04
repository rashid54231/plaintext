import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';

class LocalStorageService {
  static final LocalStorageService instance = LocalStorageService._();
  LocalStorageService._();

  static const String _tasksBoxName = 'tasksBox';
  static const String _syncQueueBoxName = 'syncQueueBox';

  late Box _tasksBox;
  late Box _syncQueueBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _tasksBox = await Hive.openBox(_tasksBoxName);
    _syncQueueBox = await Hive.openBox(_syncQueueBoxName);
  }

  // ============================================
  // TASKS
  // ============================================
  
  Future<void> saveTasks(List<Task> tasks) async {
    final Map<String, dynamic> tasksMap = {
      for (var t in tasks) t.id!: t.toMap()
    };
    await _tasksBox.putAll(tasksMap);
  }

  Future<void> saveTask(Task task) async {
    await _tasksBox.put(task.id!, task.toMap());
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksBox.delete(taskId);
  }

  List<Task> getAllTasks() {
    return _tasksBox.values.map((e) {
      final map = Map<String, dynamic>.from(e);
      return Task.fromMap(map);
    }).toList();
  }

  // ============================================
  // SYNC QUEUE
  // ============================================
  
  Future<void> enqueueSyncAction(String action, String type, Map<String, dynamic> data) async {
    final syncItem = {
      'action': action, // 'CREATE', 'UPDATE', 'DELETE'
      'type': type,     // 'task', 'comment', etc.
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _syncQueueBox.add(syncItem);
  }

  List<Map<String, dynamic>> getSyncQueue() {
    return _syncQueueBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  List<dynamic> getSyncQueueKeys() {
    return _syncQueueBox.keys.toList();
  }

  Future<void> removeSyncAction(dynamic key) async {
    await _syncQueueBox.delete(key);
  }
}
