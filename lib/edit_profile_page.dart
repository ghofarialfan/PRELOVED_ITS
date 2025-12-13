import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  String? _avatarUrl;
  bool _loading = true;

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      _emailCtrl.text = user.email ?? '';
      final resId = await client.from('users').select().eq('id', user.id).limit(1);
      var list = (resId as List<dynamic>);
      if (list.isNotEmpty) {
        final m = list.first as Map<String, dynamic>;
        _nameCtrl.text = (m['full_name'] ?? '').toString();
        _bioCtrl.text = (m['bio'] ?? '').toString();
        _linkCtrl.text = (m['link'] ?? '').toString();
        _avatarUrl = (m['avatar_url'] ?? m['photo_url'] ?? '').toString();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final username = (user.email ?? '').split('@').first;
      final payload = {
        'id': user.id,
        'full_name': _nameCtrl.text.trim(),
        if (_avatarUrl != null) 'photo_url': _avatarUrl,
        if ((user.email ?? '').isNotEmpty) 'email': user.email,
        'username': username.isNotEmpty ? username : _nameCtrl.text.trim(),
        if (_bioCtrl.text.trim().isNotEmpty) 'bio': _bioCtrl.text.trim(),
        if (_linkCtrl.text.trim().isNotEmpty) 'link': _linkCtrl.text.trim(),
      };
      await client.from('users').upsert(payload, onConflict: 'id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan disimpan')));
      Navigator.pop(context, _nameCtrl.text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: ${e.toString()}')));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _emailCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    const blueSoft = Color(0xFFE9F0FF);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Profil'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: blueSoft,
                          backgroundImage:
                              _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () async {
                              final newUrl = await Navigator.pushNamed(context, '/edit_photo');
                              if (newUrl is String && newUrl.isNotEmpty) {
                                setState(() => _avatarUrl = newUrl);
                              }
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(CupertinoIcons.pencil, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Profil kamu', style: TextStyle(fontSize: 14, color: Colors.black54)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Input(label: 'Nama Pengguna', controller: _nameCtrl),
                const SizedBox(height: 10),
                _Input(label: 'Bio', controller: _bioCtrl),
                const SizedBox(height: 10),
                _Input(label: 'Email', controller: _emailCtrl, readOnly: true),
                const SizedBox(height: 10),
                _Input(label: 'Link', controller: _linkCtrl),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _save,
                  child: const Text('Simpan Perubahan'),
                ),
              ],
            ),
    );
  }
}

class _Input extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  const _Input({required this.label, required this.controller, this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    const blueSoft = Color(0xFFE9F0FF);
    return TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: blueSoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2)),
      ),
    );
  }
}
