import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_password_page.dart';

class LoginEmailPage extends StatefulWidget {
  const LoginEmailPage({super.key});

  @override
  State<LoginEmailPage> createState() => _LoginEmailPageState();
}

class _LoginEmailPageState extends State<LoginEmailPage> {
  final _emailC = TextEditingController();
  bool _loading = false;

  // ===== Style tokens (samakan feel dengan Figma, tapi tanpa SVG/bubble)
  static const Color _primary = Color(0xFF0051FF);
  static const Color _bg = Colors.white;
  static const Color _fieldFill = Color(0xFFF3F5F7);
  static const Color _textStrong = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _emailPrefix(String email) {
    final at = email.indexOf('@');
    return (at > 0) ? email.substring(0, at) : email;
  }

  Future<void> _next() async {
    if (_loading) return;

    final email = _emailC.text.trim().toLowerCase();
    if (email.isEmpty) {
      _snack('Email wajib diisi.');
      return;
    }

    setState(() => _loading = true);
    try {
      // OPTIONAL: ambil data profil kalau sudah ada di public.users
      // Kalau belum ada row, tetap lanjut ke password (biar tidak false "belum terdaftar")
      final userRow = await AuthService.instance.getUserByEmail(email);

      if (!mounted) return;

      final displayName = (userRow?['full_name']?.toString().trim().isNotEmpty ?? false)
          ? userRow!['full_name'].toString()
          : (userRow?['username']?.toString().trim().isNotEmpty ?? false)
              ? userRow!['username'].toString()
              : _emailPrefix(email);

      final photoUrl =
          (userRow?['photo_url'] ?? userRow?['profile_image_url'])?.toString();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPasswordPage(
            email: email,
            displayName: displayName,
            photoUrl: photoUrl,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      // Kalau query public.users gagal pun, tetap lanjut
      final email = _emailC.text.trim().toLowerCase();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPasswordPage(
            email: email,
            displayName: _emailPrefix(email),
            photoUrl: null,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _pillDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar: Batalkan (sesuai arahan kamu: kembali ke halaman sebelumnya)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    ),
                    child: const Text(
                      'Batalkan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Title
                const Text(
                  'Masuk',
                  style: TextStyle(
                    fontSize: 44,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: _textStrong,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Senang melihat kamu kembali!',
                  style: TextStyle(color: _textMuted, fontSize: 14),
                ),

                const SizedBox(height: 26),

                // Email field
                TextField(
                  controller: _emailC,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _loading ? null : _next(),
                  decoration: _pillDecoration(
                    hint: 'Email',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    suffixIcon: (_emailC.text.trim().isEmpty)
                        ? null
                        : IconButton(
                            onPressed: () {
                              _emailC.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 18),

                // Primary button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Selanjutnya',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                // Links
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/register',
                      (r) => false,
                    ),
                    child: const Text(
                      'Belum punya akun? Buat Akun',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/reset'),
                    child: const Text(
                      'Lupa kata sandi?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const Spacer(),

                // Bottom helper (biar layout "full", rapi dari atas ke bawah)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Center(
                    child: Text(
                      'Preloved ITS',
                      style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
