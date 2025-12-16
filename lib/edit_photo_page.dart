import 'package:image_picker/image_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crop_your_image/crop_your_image.dart';

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
  Uint8List? _croppedBytes;
  final CropController _cropController = CropController();
  Completer<Uint8List>? _pendingCropCompleter;

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
      _croppedBytes = null;
    });
  }

  Future<void> _save() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      String? finalUrl = _avatarUrl;

      if (_pickedBytes != null) {
        _pendingCropCompleter = Completer<Uint8List>();
        _cropController.crop();
        final cropped = await _pendingCropCompleter!.future;
        _croppedBytes = cropped;
        final path = 'profile_photos/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await client.storage
            .from('photo_url_pp')
            .uploadBinary(
              path,
              _croppedBytes ?? _pickedBytes!,
              fileOptions: FileOptions(
                contentType: _croppedBytes != null ? 'image/png' : (_pickedMime ?? 'image/jpeg'),
                upsert: true,
              ),
            );
        finalUrl = client.storage.from('photo_url_pp').getPublicUrl(path);
      }

      if (finalUrl != null && finalUrl.isNotEmpty) {
        final username = (user.email ?? '').split('@').first;
        final existing = await client
            .from('users')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();
        final existingName = (existing?['full_name'] ?? '').toString();
        final meta = user.userMetadata ?? {};
        final candidateName = existingName.isNotEmpty
            ? existingName
            : (meta['full_name'] ??
                    meta['name'] ??
                    user.email?.split('@').first ??
                    '')
                .toString();
        await client.from('users').upsert({
          'id': user.id,
          'photo_url': finalUrl,
          'full_name': candidateName.isNotEmpty ? candidateName : username,
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
    const iosBlue = Color(0xFF007AFF);
    const greySoft = Color(0xFFF2F2F7);
    ImageProvider? avatar;
    if (_pickedBytes != null) {
      avatar = MemoryImage(_pickedBytes!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      avatar = NetworkImage(_avatarUrl!);
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.pop(context)),
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
                const Text('Edit Foto', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Pilih Foto Kamu', style: TextStyle(color: Colors.black54, fontSize: 14)),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(0xFFE5E5EA), width: 2),
                      ),
                      child: SizedBox(
                        width: 168,
                        height: 168,
                        child: (_pickedBytes != null)
                            ? Crop(
                                image: _pickedBytes!,
                                controller: _cropController,
                                onCropped: (result) {
                                  try {
                                    final r = result as dynamic;
                                    final bytes = r.croppedImage as Uint8List?;
                                    if (bytes != null) {
                                      _pendingCropCompleter?.complete(bytes);
                                      setState(() => _croppedBytes = bytes);
                                    } else {
                                      _pendingCropCompleter?.completeError(r.error ?? 'Crop failed');
                                    }
                                  } catch (e) {
                                    _pendingCropCompleter?.completeError(e);
                                  }
                                },
                                withCircleUi: true,
                                interactive: true,
                                initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                                  size: 1,
                                  aspectRatio: 1,
                                ),
                                baseColor: Colors.transparent,
                                maskColor: Colors.white.withAlpha(90),
                                radius: 168,
                                progressIndicator: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : CircleAvatar(radius: 84, backgroundColor: greySoft, backgroundImage: avatar),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greySoft,
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _pickFromGallery,
                  child: const Text('Galeri'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iosBlue,
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
