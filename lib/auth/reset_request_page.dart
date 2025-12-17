import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ResetRequestPage extends StatefulWidget {
  const ResetRequestPage({super.key});

  @override
  State<ResetRequestPage> createState() => _ResetRequestPageState();
}

class _ResetRequestPageState extends State<ResetRequestPage> {
  final _emailC = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailC.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.sendResetPasswordEmail(email);

      if (!mounted) return;
      _snack('Link reset sudah dikirim ke email kamu. Cek inbox/spam.');
      Navigator.pop(context); // kembali ke halaman sebelumnya
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal kirim reset email: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _pillDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF3F5F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF0051FF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(),

              const Icon(Icons.lock_reset_rounded, size: 70, color: primary),
              const SizedBox(height: 14),

              const Text(
                'Lupa Kata Sandi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),

              const Text(
                'Masukkan email akunmu,\nkami kirim link reset password.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16, height: 1.35),
              ),
              const SizedBox(height: 22),

              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: _pillDecoration('Email'),
              ),

              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _loading ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Kirim Link Reset',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Batalkan',
                  style: TextStyle(color: Colors.black54, fontSize: 16),
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
