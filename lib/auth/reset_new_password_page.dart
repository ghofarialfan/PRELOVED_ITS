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

  static const _primary = Color(0xFF0051FF);
  static const _fieldFill = Color(0xFFF3F5F9);

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
    } catch (_) {}
  }

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _pill(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _save() async {
    if (_loading) return;

    final a = _p1.text.trim();
    final b = _p2.text.trim();

    if (a.isEmpty || b.isEmpty) {
      _snack('Password wajib diisi.');
      return;
    }
    if (a != b) {
      _snack('Password tidak sama.');
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _snack('Session reset belum aktif. Buka link reset dari email dulu.');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ polos
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),

                      const Icon(Icons.password_rounded,
                          size: 72, color: _primary),
                      const SizedBox(height: 14),

                      const Text(
                        'Buat Kata Sandi Baru',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text(
                        'Masukkan kata sandi baru untuk akunmu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),

                      TextField(
                        controller: _p1,
                        obscureText: true,
                        decoration: _pill('Kata Sandi Baru'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _p2,
                        obscureText: true,
                        decoration: _pill('Ulangi Kata Sandi Baru'),
                      ),

                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _primary.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Simpan',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batalkan'),
                      ),

                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
