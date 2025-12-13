import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class ResetNewPasswordPage extends StatefulWidget {
  const ResetNewPasswordPage({super.key});

  @override
  State<ResetNewPasswordPage> createState() => _ResetNewPasswordPageState();
}

class _ResetNewPasswordPageState extends State<ResetNewPasswordPage> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _consumeCodeIfAny();
  }

  Future<void> _consumeCodeIfAny() async {
    if (!kIsWeb) return;

    final code = Uri.base.queryParameters['code'];
    if (code == null || code.isEmpty) return;

    try {
      await Supabase.instance.client.auth.exchangeCodeForSession(code);
    } catch (_) {
      // kalau gagal, tombol simpan akan kasih pesan
    }
  }

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_loading) return;

    final a = _p1.text.trim();
    final b = _p2.text.trim();

    if (a.isEmpty || b.isEmpty) {
      _snack('Password wajib diisi.');
      return;
    }
    if (a.length < 6) {
      _snack('Password minimal 6 karakter.');
      return;
    }
    if (a != b) {
      _snack('Password tidak sama.');
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _snack('Session reset belum aktif. Buka link reset dari email terlebih dulu.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.updatePassword(a);
      if (!mounted) return;

      _snack('Password berhasil diperbarui. Silakan login.');

      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal update password: $e');
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
      appBar: AppBar(title: const Text('Buat Kata Sandi Baru')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Masukkan kata sandi baru untuk akunmu.'),
            const SizedBox(height: 14),
            TextField(
              controller: _p1,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Kata Sandi Baru',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _p2,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Ulangi Kata Sandi Baru',
                filled: true,
                fillColor: Colors.white,
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
                onPressed: _loading ? null : _save,
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
                    : const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
