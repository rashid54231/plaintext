import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/file_picker_service.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  User? _currentUser;
  List<User> _students = [];
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  List<User> get students => _students;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  bool get isManager => _currentUser?.isManager ?? false;
  bool get isStudent => _currentUser?.isStudent ?? false;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _db.getUserByEmail(email.trim());
      if (user == null) {
        _error = 'No account found with this email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (user.password != password) {
        _error = 'Incorrect password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required Role role,
    String? phone,
    String? classCode,
    PlatformFile? avatarFile,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final existingUser = await _db.getUserByEmail(email.trim());
      if (existingUser != null) {
        _error = 'An account with this email already exists';
        _isLoading = false;
        notifyListeners();
        return _error;
      }

      final user = User(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        password: password,
        role: role,
        phone: phone,
        classCode: classCode,
      );

      final id = await _db.insertUserAndGetId(user);
      
      String? avatarUrl;
      if (avatarFile != null && id != null) {
        avatarUrl = await FilePickerService.instance.uploadAvatar(
          userId: id, 
          file: avatarFile
        );
        if (avatarUrl != null) {
          await _db.updateUserAvatar(id, avatarUrl);
        }
      }

      _currentUser = user.copyWith(id: id, avatarUrl: avatarUrl);

      _isLoading = false;
      notifyListeners();
      return null; // success
    } catch (e) {
      _error = 'Signup failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return _error;
    }
  }

  Future<void> loadStudents() async {
    try {
      _students = await _db.getAllStudents();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load students';
      notifyListeners();
    }
  }

  Future<bool> promoteToManager(User student) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = student.copyWith(role: Role.manager);
      await _db.updateUser(updatedUser);
      
      // Remove from students list since they are now a manager
      _students.removeWhere((s) => s.id == student.id);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to promote user: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? currentPassword,
    String? newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_currentUser == null) return false;

      if (currentPassword != null && newPassword != null) {
        if (_currentUser!.password != currentPassword) {
          _error = 'Current password is incorrect';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      final updatedUser = _currentUser!.copyWith(
        name: name,
        phone: phone,
        password: newPassword ?? _currentUser!.password,
      );

      await _db.updateUser(updatedUser);
      _currentUser = updatedUser;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Update failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateAvatar(PlatformFile file) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_currentUser == null || _currentUser!.id == null) return false;

      final avatarUrl = await FilePickerService.instance.uploadAvatar(
        userId: _currentUser!.id!,
        file: file,
      );

      if (avatarUrl != null) {
        await _db.updateUserAvatar(_currentUser!.id!, avatarUrl);
        _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Avatar update failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _students = [];
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
