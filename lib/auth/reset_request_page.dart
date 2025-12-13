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
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text('Lupa Kata Sandi')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Masukkan email akunmu, kami kirim link reset password.'),
            const SizedBox(height: 14),
            TextField(
              controller: _emailC,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Kirim Link Reset'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
