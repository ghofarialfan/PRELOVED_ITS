import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPhotoPage extends StatefulWidget {
  const EditPhotoPage({super.key});

  @override
  State<EditPhotoPage> createState() => _EditPhotoPageState();
}

class _EditPhotoPageState extends State<EditPhotoPage> {
  String? _avatarUrl;
  Uint8List? _pickedBytes;
  String? _pickedMime;
  bool _loading = true;

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final resId = await client.from('users').select().eq('id', user.id).limit(1);
      var list = (resId as List<dynamic>);
      if (list.isNotEmpty) {
        final m = list.first as Map<String, dynamic>;
        _avatarUrl = (m['avatar_url'] ?? m['photo_url'] ?? '').toString();
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedMime = 'image/jpeg';
      _avatarUrl = null;
    });
  }

  Future<void> _save() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      String? finalUrl = _avatarUrl;

      if (_pickedBytes != null) {
        final path = 'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage.from('avatars').uploadBinary(path, _pickedBytes!, fileOptions: FileOptions(contentType: _pickedMime ?? 'image/jpeg', upsert: true));
        finalUrl = client.storage.from('avatars').getPublicUrl(path);
      }

      if (finalUrl != null && finalUrl.isNotEmpty) {
        final username = (user.email ?? '').split('@').first;
        await client.from('users').upsert({
          'id': user.id,
          'photo_url': finalUrl,
          if ((user.email ?? '').isNotEmpty) 'email': user.email,
          'username': username.isNotEmpty ? username : null,
        }, onConflict: 'id');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto disimpan')));
      Navigator.pop(context, finalUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan foto: ${e.toString()}')));
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    const blueSoft = Color(0xFFE9F0FF);
    ImageProvider? avatar;
    if (_pickedBytes != null) {
      avatar = MemoryImage(_pickedBytes!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatar = NetworkImage(_avatarUrl!);
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Foto'),
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
                const Text('Pilih Foto Kamu', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(100), boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6)),
                  ]),
                  child: CircleAvatar(radius: 84, backgroundColor: blueSoft, backgroundImage: avatar),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueSoft,
                    foregroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _pickFromGallery,
                  child: const Text('Galeri'),
                ),
                const SizedBox(height: 10),
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
