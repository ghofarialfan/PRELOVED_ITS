import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  File? _photo; // preview lokal

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _phoneC.dispose();
    super.dispose();
  }

  // =========================
  // PICK PHOTO (PREVIEW)
  // =========================
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null) {
      setState(() => _photo = File(x.path));
    }
  }

  // =========================
  // UPLOAD PHOTO TO STORAGE
  // =========================
  Future<String?> _uploadPhoto(String userId) async {
    if (_photo == null) return null;

    final fileExt = _photo!.path.split('.').last;
    final filePath = 'avatars/$userId.$fileExt';

    await Supabase.instance.client.storage
        .from('avatars')
        .upload(
          filePath,
          _photo!,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(filePath);

    return url;
  }

  // =========================
  // SUBMIT REGISTER
  // =========================
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
      // 1️⃣ Sign up auth
      await AuthService.instance.signUp(
        email: email,
        password: pass,
        phone: phone,
      );

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User tidak ditemukan';

      // 2️⃣ Upload foto (kalau ada)
      final photoUrl = await _uploadPhoto(user.id);

      // 3️⃣ Update row users (photo_url)
      await Supabase.instance.client.from('users').update({
        'photo_url': photoUrl,
      }).eq('id', user.id);

      if (!mounted) return;

      _snack('Akun berhasil dibuat. Silakan login.');
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

  InputDecoration _inputStyle(String hint,
      {Widget? suffix, Widget? prefix}) {
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
      suffixIcon: suffix,
      prefixIcon: prefix,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =========================
              // TITLE
              // =========================
              const Text(
                'Buat\nAkun',
                style: TextStyle(
                  fontSize: 42,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 24),

              // =========================
              // PHOTO PICKER
              // =========================
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

              // =========================
              // FORM
              // =========================
              TextField(
                controller: _emailC,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputStyle('Email'),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _passC,
                obscureText: _obscure,
                decoration: _inputStyle(
                  'Kata Sandi',
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _phoneC,
                keyboardType: TextInputType.phone,
                decoration: _inputStyle(
                  'Nomor Telepon',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: Text('🇮🇩', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),

              const Spacer(),

              // =========================
              // BUTTONS
              // =========================
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
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Selanjutnya',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500),
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
