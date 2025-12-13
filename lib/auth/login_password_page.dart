import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPasswordPage extends StatefulWidget {
  final String email;
  final String displayName;
  final String? photoUrl;

  const LoginPasswordPage({
    super.key,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  @override
  State<LoginPasswordPage> createState() => _LoginPasswordPageState();
}

class _LoginPasswordPageState extends State<LoginPasswordPage> {
  final _passC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final pass = _passC.text;
    if (pass.isEmpty) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.signIn(email: widget.email, password: pass);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } catch (e) {
      if (!mounted) return;
      _snack('Password salah / login gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.photoUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                child: (avatar == null || avatar.isEmpty)
                    ? const Icon(Icons.person, size: 34, color: Color(0xFF2563FF))
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Halo, ${widget.displayName}!!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 22),
              const Text('Ketik kata sandi kamu', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),

              TextField(
                controller: _passC,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/reset'),
                    child: const Text('Lupa kata sandi?'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Masuk'),
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false),
                child: const Text('Bukan kamu?'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
