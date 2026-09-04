import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'database_service.dart';
import '../models/task.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  SyncService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isSyncing = false;
  
  final LocalStorageService _storage = LocalStorageService.instance;
  final DatabaseService _db = DatabaseService.instance;

  void init() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        syncNow();
      }
    });
    // Attempt sync on startup if online
    syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    _isSyncing = true;
    try {
      final keys = _storage.getSyncQueueKeys();
      final queue = _storage.getSyncQueue();

      for (int i = 0; i < queue.length; i++) {
        final item = queue[i];
        final key = keys[i];
        
        bool success = await _processSyncItem(item);
        if (success) {
          await _storage.removeSyncAction(key);
        }
      }
      
      // After syncing queue, let's also fetch fresh data from server to keep local DB updated
      if (queue.isNotEmpty) {
        // A full refresh would be handled by the provider, but we can trigger it or just rely on Realtime
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _processSyncItem(Map<String, dynamic> item) async {
    try {
      final action = item['action'] as String;
      final type = item['type'] as String;
      final data = item['data'] as Map<String, dynamic>;

      if (type == 'task') {
        final task = Task.fromMap(data);
        if (action == 'CREATE') {
          // If task was created offline, we use the local UUID.
          // DatabaseService.insertTask already handles this if ID is provided in toMap().
          await _db.insertTask(task); 
        } else if (action == 'UPDATE') {
          await _db.updateTask(task);
        } else if (action == 'DELETE') {
          await _db.deleteTask(task.id!);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Failed to process sync item: $e');
      return false; // keep in queue to retry later
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
