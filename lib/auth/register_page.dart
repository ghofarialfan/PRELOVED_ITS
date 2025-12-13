import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _phoneC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _phoneC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return; // cegah double tap

    final email = _emailC.text.trim().toLowerCase();
    final pass = _passC.text;
    final phone = _phoneC.text.trim();

    if (email.isEmpty || pass.isEmpty || phone.isEmpty) {
      _snack('Email, password, dan nomor telepon wajib diisi.');
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.signUp(
        email: email,
        password: pass,
        phone: phone,
      );

      if (!mounted) return;

      _snack('Akun berhasil dibuat! Silakan cek email untuk verifikasi, lalu login.');

      // Karena email confirmation ON, jangan langsung ke Home.
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } catch (e) {
      if (!mounted) return;
      _snack('Register gagal: $e');
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
                'Buat\nAkun',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),

              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
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
                controller: _passC,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'Kata Sandi',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _phoneC,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Nomor Telepon',
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
                  onPressed: _loading ? null : _submit,
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
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false),
                  child: const Text('Sudah punya akun? Masuk'),
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
