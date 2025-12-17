import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  File? _photo;

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _phoneC.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) {
      setState(() => _photo = File(x.path));
    }
  }

  Future<void> _submit() async {
    if (_loading) return;

    final email = _emailC.text.trim().toLowerCase();
    final pass = _passC.text;
    final phone = _phoneC.text.trim();

    if (email.isEmpty || pass.isEmpty || phone.isEmpty) {
      _snack('Semua field wajib diisi.');
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

      _snack(
        'Akun berhasil dibuat. Silakan cek email untuk verifikasi, lalu login.',
      );

      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } catch (e) {
      if (!mounted) return;
      _snack('Register gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _inputStyle({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF3F5F7),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
    const primary = Color(0xFF0051FF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buat\nAkun',
                style: TextStyle(
                  fontSize: 42,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 24),

              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primary, width: 2),
                    color: const Color(0xFFF3F5F7),
                    image: _photo != null
                        ? DecorationImage(
                            image: FileImage(_photo!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _photo == null
                      ? const Icon(Icons.camera_alt_outlined,
                          color: primary, size: 28)
                      : null,
                ),
              ),

              const SizedBox(height: 28),

              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputStyle(hint: 'Email'),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _passC,
                obscureText: _obscure,
                decoration: _inputStyle(
                  hint: 'Kata Sandi',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              /// 🔧 FIX FLAG ALIGNMENT
              TextField(
                controller: _phoneC,
                keyboardType: TextInputType.phone,
                decoration: _inputStyle(
                  hint: 'Nomor Telepon',
                  prefixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(width: 14),
                      Text('🇮🇩', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
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
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Selanjutnya',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Batalkan',
                    style: TextStyle(color: Colors.black54),
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
