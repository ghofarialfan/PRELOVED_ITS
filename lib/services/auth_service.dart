import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  SupabaseClient get _db => Supabase.instance.client;

  // =========================
  // GET USER BY EMAIL (public.users)
  // =========================
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    return await _db.from('users').select().eq('email', email).maybeSingle();
  }

  // =========================
  // ENSURE USERS ROW (aman untuk login flow)
  // =========================
  Future<void> ensureUserRow({
    required String uid,
    required String email,
    String? fullName,
    String? phone,
    String? photoUrl,
  }) async {
    final username = email.split('@').first;

    // Pakai UPSERT biar:
    // - tidak gagal kalau row sudah ada
    // - bisa "nambahin" field yang null sebelumnya
    await _db.from('users').upsert(
      {
        'id': uid, // harus sama dengan auth.uid()
        'email': email,
        'username': username,
        'full_name': (fullName == null || fullName.isEmpty) ? username : fullName,
        'phone': phone,
        'photo_url': photoUrl,
      },
      onConflict: 'id',
    );
  }

  // =========================
  // SIGN UP (FIX: jangan gagal karena RLS insert users)
  // =========================
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String phone,
    String? fullName,
    String? photoUrl,
  }) async {
    final origin = Uri.base.origin;

    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {
        'phone': phone,
        'full_name': fullName,
        'photo_url': photoUrl,
      },
      // setelah verifikasi email, balik ke login
      emailRedirectTo: '$origin/#/login',
    );

    final user = res.user;
    if (user == null) {
      throw const AuthException('Gagal membuat akun.');
    }

    // PENTING:
    // - Kalau Email Confirmation ON, biasanya session = null sampai user verifikasi email.
    // - Insert ke public.users di sini sering kena RLS (dan bikin "Register gagal" padahal user sudah tercipta).
    //
    // Jadi: hanya "coba" tulis ke public.users jika session sudah ada.
    // Kalau gagal karena RLS, jangan dianggap gagal register.
    if (res.session != null) {
      try {
        await ensureUserRow(
          uid: user.id,
          email: email,
          phone: phone,
          fullName: fullName,
          photoUrl: photoUrl,
        );
      } on PostgrestException {
        // abaikan: user auth sudah tercipta & email verifikasi tetap terkirim
      }
    }

    return res;
  }

  // =========================
  // SIGN IN
  // =========================
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _db.auth.signInWithPassword(email: email, password: password);

    final user = res.user;
    if (user == null) throw const AuthException('Login gagal.');

    await ensureUserRow(
      uid: user.id,
      email: user.email ?? email,
      phone: user.userMetadata?['phone']?.toString(),
      fullName: user.userMetadata?['full_name']?.toString(),
      photoUrl: user.userMetadata?['photo_url']?.toString(),
    );
  }

  // =========================
  // SIGN OUT
  // =========================
  Future<void> signOut() => _db.auth.signOut();

  // =========================
  // RESET PASSWORD
  // =========================
  Future<void> sendResetPasswordEmail(String email) async {
    final origin = Uri.base.origin;
    await _db.auth.resetPasswordForEmail(
      email,
      redirectTo: '$origin/#/reset-new',
    );
  }

  // =========================
  // UPDATE PASSWORD
  // =========================
  Future<void> updatePassword(String newPassword) async {
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }
}
