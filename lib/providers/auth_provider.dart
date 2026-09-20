import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

const String _userProfileKey = 'user_profile_data';

/// Helper function to load initial saved user profile before runApp()
Future<UserProfile?> getSavedUserProfile() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userProfileKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final profile = UserProfile.fromMap(map);
      if (profile.isProfileComplete) {
        return profile;
      }
    }
  } catch (_) {}
  return null;
}

class AuthNotifier extends StateNotifier<UserProfile?> {
  AuthNotifier(super.initialUser);

  Future<void> saveProfile(UserProfile profile) async {
    state = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userProfileKey, jsonEncode(profile.toMap()));
    } catch (_) {}
  }

  Future<void> logout() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userProfileKey);
    } catch (_) {}
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserProfile?>((ref) {
  return AuthNotifier(null);
});
