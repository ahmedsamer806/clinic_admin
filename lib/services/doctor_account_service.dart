import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Creates doctor Auth users without signing out the current admin session.
/// Uses the Auth REST API directly so we don't need a second SupabaseClient
/// (which would require asyncStorage for PKCE on web).
class DoctorAccountService {
  /// Registers a new Supabase Auth user for the doctor.
  /// Requires: Auth → Providers → Email enabled, and email confirmation off
  /// (or the doctor must confirm before first login).
  static Future<String> createAuthUser({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final url = Uri.parse('${AppConfig.supabaseUrl}/auth/v1/signup');
    final response = await http.post(
      url,
      headers: {
        'apikey': AppConfig.supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'data': {
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          'role': 'doctor',
        },
      }),
    );

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthException(
        'تعذّر إنشاء حساب الطبيب (استجابة غير متوقعة من الخادم).',
      );
    }

    if (response.statusCode >= 400) {
      final msg = (body['msg'] ??
              body['error_description'] ??
              body['message'] ??
              'تعذّر إنشاء حساب الطبيب.')
          .toString();
      throw AuthException(msg);
    }

    final user = body['user'] as Map<String, dynamic>?;
    final userId = user?['id'] as String?;
    if (userId == null || userId.isEmpty) {
      throw AuthException(
        'تعذّر إنشاء حساب الطبيب. تحقق من إعدادات التسجيل في Supabase (Auth → Email).',
      );
    }

    return userId;
  }

  static String friendlyAuthError(Object e) {
    final msg = e.toString();
    if (msg.contains('already registered') ||
        msg.contains('User already registered') ||
        msg.contains('duplicate') ||
        msg.contains('already been registered')) {
      return 'البريد الإلكتروني مستخدم مسبقاً.';
    }
    if (msg.contains('Password') || msg.contains('password')) {
      return 'كلمة المرور ضعيفة أو قصيرة (6 أحرف على الأقل).';
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return 'البريد الإلكتروني غير صالح.';
    }
    if (msg.contains('signup') ||
        msg.contains('Signups not allowed') ||
        msg.contains('signups_disabled')) {
      return 'التسجيل معطّل في Supabase. فعّل Signups من Auth → Providers → Email.';
    }
    return msg
        .replaceFirst('AuthException: ', '')
        .replaceFirst('Exception: ', '');
  }
}
