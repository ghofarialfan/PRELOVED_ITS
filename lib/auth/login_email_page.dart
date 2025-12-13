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

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
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
      // ✅ OPTIONAL: ambil data profil kalau sudah ada di public.users
      final userRow = await AuthService.instance.getUserByEmail(email);

      // ✅ Kalau belum ada row, tetap lanjut ke password (Opsi B)
      final displayName = (userRow?['full_name'] ??
              userRow?['username'] ??
              email.split('@').first)
          .toString();

      final photoUrl =
          (userRow?['photo_url'] ?? userRow?['profile_image_url'])?.toString();

      if (!mounted) return;

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
    } catch (e) {
      if (!mounted) return;
      // Kalau query public.users gagal pun, tetap lanjut
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPasswordPage(
            email: email,
            displayName: email.split('@').first,
            photoUrl: null,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text(
                'Masuk',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Senang Melihat Kamu Kembali!  🖤',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Selanjutnya'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamedAndRemoveUntil(context, '/register', (r) => false),
                  child: const Text('Belum punya akun? Buat Akun'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/reset'),
                  child: const Text('Lupa kata sandi?'),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
