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
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _passC.addListener(() {
      if (_error) setState(() => _error = false);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final pass = _passC.text; // ✅ UNLIMITED, tidak dibatasi
    if (pass.isEmpty) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.signIn(email: widget.email, password: pass);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = true);
      _snack('Password salah / login gagal');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _dot({required bool filled}) {
    final filledColor = _error ? const Color(0xFFEF4444) : const Color(0xFF0051FF);
    const emptyColor = Color(0xFFD9E4FF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? filledColor : emptyColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.photoUrl;
    final typed = _passC.text.length;

    // indikator visual saja (bukan limit)
    const slots = 10;
    final filled = _error ? slots : (typed >= slots ? slots : typed);
    final extra = (!_error && typed > slots) ? typed - slots : 0;

    return Scaffold(
      backgroundColor: Colors.white, // ✅ polos
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context), // ✅ Batalkan = kembali
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // Avatar
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: Colors.black.withValues(alpha: 0.08),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFFFFC1DC),
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? const Icon(Icons.person, size: 42, color: Colors.white)
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Halo, ${widget.displayName}!!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F1F1F),
                  height: 1.05,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Ketik kata sandi kamu',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              // indikator dots (visual)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: List.generate(slots, (i) {
                      final isFilled = i < filled;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _dot(filled: isFilled),
                      );
                    }),
                  ),
                  if (extra > 0) ...[
                    const SizedBox(width: 10),
                    Text(
                      '+$extra',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 18),

              // TextField password (UNLIMITED)
              TextField(
                controller: _passC,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: const Color(0xFFF4F7FF),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading ? null : () => Navigator.pushNamed(context, '/reset'),
                  child: const Text(
                    'Lupa kata sandi?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0051FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Bukan kamu?
              InkWell(
                onTap: _loading
                    ? null
                    : () => Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false),
                borderRadius: BorderRadius.circular(40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Bukan Kamu?',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0051FF),
                        ),
                        child: const Icon(Icons.arrow_forward, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0051FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Masuk',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
