import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthStorageService {
  static final AuthStorageService instance = AuthStorageService._();
  AuthStorageService._();

  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserData = 'auth_user_data';
  static const String _keyIsLoggedIn = 'auth_is_logged_in';

  /// Saves the active user session to SharedPreferences
  Future<void> saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final userMap = user.toMap();
    final jsonString = jsonEncode(userMap);

    await Future.wait([
      prefs.setString(_keyUserId, user.id ?? ''),
      prefs.setString(_keyUserData, jsonString),
      prefs.setBool(_keyIsLoggedIn, true),
    ]);
  }

  /// Retrieves the saved user session if available
  Future<User?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      if (!isLoggedIn) return null;

      final userData = prefs.getString(_keyUserData);
      if (userData == null || userData.isEmpty) return null;

      final userMap = jsonDecode(userData) as Map<String, dynamic>;
      return User.fromMap(userMap);
    } catch (e) {
      return null;
    }
  }

  /// Clears the active session from SharedPreferences
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserData),
      prefs.setBool(_keyIsLoggedIn, false),
    ]);
  }

  /// Fast synchronous-like check if an active session flag exists
  Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }
}
