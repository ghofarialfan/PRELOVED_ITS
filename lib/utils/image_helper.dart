import 'package:supabase_flutter/supabase_flutter.dart';

class ImageHelper {
  static final _client = Supabase.instance.client;
  //Konversi Data Mentah
  static Future<List<Map<String, dynamic>>> processImages(List<dynamic> rows) async {
    final maps = rows.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
    final ids = maps.map((m) => (m['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return maps;

    try {
      final grouped = <String, String>{};
      final coverIdByProduct = <String, String>{};

      for (final m in maps) {
        final pid = (m['id'] ?? '').toString();
        final cid = (m['product_image_id'] ?? '').toString();
        if (pid.isNotEmpty && cid.isNotEmpty) coverIdByProduct[pid] = cid;
      }

      // Ambil gambar cover berdasarkan ID cover
      if (coverIdByProduct.isNotEmpty) {
        final coverIds = coverIdByProduct.values.toList();
        final coverRows = await _client
            .from('product_images')
            .select('id, image_url')
            .filter('id', 'in', '(${coverIds.map((e) => '"$e"').join(",")})');
        
        for (final row in (coverRows as List<dynamic>)) {
          final id = row['id'].toString();
          final path = row['image_url'].toString();
          if (id.isNotEmpty && path.isNotEmpty) {
            coverIdByProduct.forEach((pid, cid) {
              if (cid == id) grouped[pid] = path;
            });
          }
        }
      }

      // Jika masih ada yang kosong, ambil gambar pertama dari product_images
      final missing = ids.where((pid) => !grouped.containsKey(pid));
      for (final pid in missing) {
        final img = await _client
            .from('product_images')
            .select('image_url')
            .eq('product_id', pid)
            .order('order_index', ascending: true)
            .limit(1)
            .maybeSingle();
        if (img != null) grouped[pid] = img['image_url'].toString();
      }

      // Convert Path menjadi URL Publik Supabase
      for (final m in maps) {
        final pid = m['id'].toString();
        var path = grouped[pid] ?? '';
        if (path.isNotEmpty) {
          if (path.startsWith('http')) {
            m['image_url'] = path;
          } else {
            var normalized = path.trim().replaceFirst(RegExp(r'^/+'), '');
            if (!normalized.contains('/')) normalized = 'products/$normalized';
            m['image_url'] = _client.storage.from('products').getPublicUrl(normalized);
          }
        }
      }
    } catch (e) {
      print('Image Helper Error: $e');
    }
    return maps;
  }
}