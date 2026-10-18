import 'package:flutter/foundation.dart';

import '../../../models/user_model.dart';
import 'auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;
  UserModel? user;
  String? token;

  Future<void> loginWithPassword({
    String? email,
    String? phone,
    required String password,
  }) async {
    final data = await _authService.loginWithPassword(
      phone: phone,
      email: email,
      password: password,
    );
    token = data['token'] as String?;
    user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<String?> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      await loginWithPassword(email: email, phone: phone, password: password);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> sendOtp(String email) async {
    await _authService.sendOtp(email);
  }

  Future<void> verifyOtp({required String email, required String otp}) async {
    final data = await _authService.verifyOtp(email: email, otp: otp);
    token = data['token'] as String?;
    user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<String?> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? role,
  }) async {
    try {
      final data = await _authService.signUp(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );
      token = data['token'] as String?;
      user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
