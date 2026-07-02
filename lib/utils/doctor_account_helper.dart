/// Helpers for reading nested `doctor_accounts` rows from Supabase joins.
Map<String, dynamic>? doctorAccountFrom(Map<String, dynamic>? doctor) {
  if (doctor == null) return null;
  final raw = doctor['doctor_accounts'];
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty) {
    final first = raw.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
  }
  return null;
}

const doctorAccountsSelect = '''
  doctor_accounts (
    id, service_provider_id, auth_user_id, login_email, login_password, created_at
  )
''';
