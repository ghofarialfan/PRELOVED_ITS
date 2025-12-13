import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  SupabaseClient get _db => Supabase.instance.client;

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    return await _db.from('users').select().eq('email', email).maybeSingle();
  }

  Future<void> ensureUserRow({
    required String uid,
    required String email,
    String? fullName,
    String? phone,
    String? photoUrl,
  }) async {
    final existing =
        await _db.from('users').select('id').eq('id', uid).maybeSingle();
    if (existing != null) return;

    final username = email.split('@').first;

    await _db.from('users').insert({
      'id': uid,
      'email': email,
      'username': username,
      'full_name': fullName ?? username,
      'phone': phone,
      'photo_url': photoUrl,
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String phone,
  }) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'phone': phone},
    );

    final user = res.user;
    if (user == null) throw const AuthException('Gagal membuat akun.');
    // Opsi B: jangan insert users di sini
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final res =
        await _db.auth.signInWithPassword(email: email, password: password);
    final user = res.user;
    if (user == null) throw const AuthException('Login gagal.');

    await ensureUserRow(
      uid: user.id,
      email: user.email ?? email,
      phone: user.userMetadata?['phone']?.toString(),
      fullName: user.userMetadata?['full_name']?.toString(),
    );
  }

  Future<void> signOut() => _db.auth.signOut();

  /// ✅ Reset password (Flutter Web)
  /// redirectTo dibuat kompatibel dengan format yang kamu dapat:
  /// http://localhost:PORT/?code=...#/reset-new
  Future<void> sendResetPasswordEmail(String email) async {
    final origin = Uri.base.origin; // contoh: http://localhost:32929
    await _db.auth.resetPasswordForEmail(
      email,
      redirectTo: '$origin/?#/reset-new',
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }
}
