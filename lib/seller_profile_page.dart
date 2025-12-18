import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ FIX: dari widgets -> product folder
import '../product/product_detail_view.dart';

class SellerProfilePage extends StatefulWidget {
  /// sellerId = sellers.id
  final String sellerId;

  const SellerProfilePage({super.key, required this.sellerId});

  @override
  State<SellerProfilePage> createState() => _SellerProfilePageState();
}

class _SellerProfilePageState extends State<SellerProfilePage> {
  final _client = Supabase.instance.client;

  static const primaryBlue = Color(0xFF2563FF);
  static const bgSoft = Color(0xFFF8FAFF);
  static const pillBg = Color(0xFFE9F0FF);

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _seller;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _reviews = [];

  double _avgRating = 0;
  int _reviewCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ✅ FUNGSI BARU: Mendapatkan URL publik dari Supabase Storage
  // Berdasarkan screenshot storage kamu, path di bucket 'products' diawali folder 'products/'
  String _getPublicUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;

    String finalPath = path;
    // Jika di database cuma nama file, tambahkan folder products/ sesuai screenshot storage
    if (!path.contains('/')) {
      finalPath = 'products/$path';
    }

    return _client.storage.from('products').getPublicUrl(finalPath);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sellerRes = await _client
          .from('sellers')
          .select(
            'id, name, username, description, location, photo_url, created_at',
          )
          .eq('id', widget.sellerId)
          .maybeSingle();

      if (sellerRes == null) {
        throw Exception(
          'Seller dengan id ${widget.sellerId} tidak ditemukan di tabel sellers.',
        );
      }

      final prodRes = await _client
          .from('products')
          .select(
            'id, name, price, discount_price, created_at, seller_id, category_id, '
            'category:categories(id,name)',
          )
          .eq('seller_id', widget.sellerId)
          .order('created_at', ascending: false);

      final products = (prodRes as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final productIds = products.map((p) => p['id'].toString()).toList();
      final Map<String, String> primaryImageByProduct = {};

      if (productIds.isNotEmpty) {
        final imgRes = await _client
            .from('product_images')
            .select('product_id, image_url, display_order, order_index')
            .inFilter('product_id', productIds)
            .order('display_order', ascending: true)
            .order('order_index', ascending: true);

        for (final row in (imgRes as List)) {
          final m = Map<String, dynamic>.from(row as Map);
          final pid = (m['product_id'] ?? '').toString();
          primaryImageByProduct.putIfAbsent(
            pid,
            () => _getPublicUrl(
              (m['image_url'] ?? '').toString(),
            ), // ✅ Gunakan Public URL
          );
        }
      }

      for (final p in products) {
        final pid = (p['id'] ?? '').toString();
        p['primary_image_url'] = primaryImageByProduct[pid] ?? '';
      }

      final Map<String, Map<String, dynamic>> catMap = {};
      for (final p in products) {
        final cat = p['category'];
        if (cat is Map && cat['id'] != null) {
          final id = cat['id'].toString();
          final name = (cat['name'] ?? 'Kategori').toString();
          catMap.putIfAbsent(id, () => {'id': id, 'name': name, 'count': 0});
          catMap[id]!['count'] = (catMap[id]!['count'] as int) + 1;
        }
      }
      final categories = catMap.values.toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      double avg = 0;
      int count = 0;
      final List<Map<String, dynamic>> reviews = [];

      if (productIds.isNotEmpty) {
        final revRes = await _client
            .from('product_reviews')
            .select(
              'id, product_id, rating, comment, created_at, image_url, '
              'user:users(id, full_name, username, profile_image_url, photo_url)',
            )
            .inFilter('product_id', productIds)
            .order('created_at', ascending: false);

        for (final r in (revRes as List)) {
          reviews.add(Map<String, dynamic>.from(r as Map));
        }

        final ratings = reviews
            .map((e) => e['rating'])
            .where((x) => x != null)
            .map((x) => (x as num).toDouble())
            .toList();

        count = ratings.length;
        if (count > 0) {
          final sum = ratings.fold<double>(0, (a, b) => a + b);
          avg = sum / count;
        }
      }

      setState(() {
        _seller = Map<String, dynamic>.from(sellerRes);
        _products = products;
        _categories = categories;
        _reviews = reviews;
        _avgRating = avg;
        _reviewCount = count;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatRupiah(num v) {
    final s = v.toStringAsFixed(0);
    final chars = s.split('');
    final out = <String>[];
    for (int i = 0; i < chars.length; i++) {
      final idxFromEnd = chars.length - i;
      out.add(chars[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) out.add('.');
    }
    return 'Rp ${out.join()}';
  }

  Widget _stars(double rating) {
    final full = rating.floor();
    final half = (rating - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < full) {
          return const Icon(
            CupertinoIcons.star_fill,
            size: 14,
            color: primaryBlue,
          );
        }
        if (i == full && half) {
          return const Icon(
            CupertinoIcons.star_lefthalf_fill,
            size: 14,
            color: primaryBlue,
          );
        }
        return Icon(
          CupertinoIcons.star,
          size: 14,
          color: primaryBlue.withValues(alpha: 0.35),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profil Penjual'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '❌ Gagal memuat data:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAll,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final seller = _seller!;
    final sellerName = (seller['name'] ?? 'Penjual').toString();
    final username = (seller['username'] ?? '').toString();
    final location = (seller['location'] ?? '').toString();
    final desc = (seller['description'] ?? '').toString();
    final photoUrl = (seller['photo_url'] ?? '').toString();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bgSoft,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(sellerName),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: pillBg,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                CupertinoIcons.person_fill,
                                size: 42,
                                color: primaryBlue,
                              ),
                            )
                          : const Icon(
                              CupertinoIcons.person_fill,
                              size: 42,
                              color: primaryBlue,
                            ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      username.isNotEmpty ? '@$username' : sellerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      location.isNotEmpty ? location : '—',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _reviewCount > 0
                          ? 'rating ${_avgRating.toStringAsFixed(1)}/5'
                          : 'rating -',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nanti diarahkan ke halaman chat 😊',
                              ),
                            ),
                          );
                        },
                        child: const Text('Chat Penjual'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const TabBar(
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.black54,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelStyle: TextStyle(fontWeight: FontWeight.w700),
                        tabs: [
                          Tab(text: 'Produk'),
                          Tab(text: 'Kategori'),
                          Tab(text: 'Ulasan'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [_productsTab(), _categoriesTab(), _reviewsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productsTab() {
    if (_products.isEmpty) return const Center(child: Text('Belum ada produk'));

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _products.length,
      itemBuilder: (context, i) {
        final p = _products[i];
        final name = (p['name'] ?? '').toString();
        final num price = (p['price'] ?? 0) as num;
        final num? discount = p['discount_price'] == null
            ? null
            : (p['discount_price'] as num);
        final num shown = (discount != null && discount > 0) ? discount : price;
        final img = (p['primary_image_url'] ?? '').toString();

        return InkWell(
          onTap: () {
            final pid = p['id'].toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailView(productId: pid),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: img.isNotEmpty
                        ? Image.network(
                            img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: pillBg,
                              child: const Icon(
                                CupertinoIcons.photo,
                                color: primaryBlue,
                              ),
                            ),
                          )
                        : Container(
                            color: pillBg,
                            child: const Icon(
                              CupertinoIcons.photo,
                              color: primaryBlue,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRupiah(shown),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _categoriesTab() {
    if (_categories.isEmpty)
      return const Center(child: Text('Belum ada kategori'));

    IconData iconFor(String name) {
      final n = name.toLowerCase();
      if (n.contains('pakaian')) return CupertinoIcons.tag;
      if (n.contains('sepatu')) return CupertinoIcons.sportscourt;
      if (n.contains('tas')) return CupertinoIcons.bag;
      if (n.contains('topi')) return CupertinoIcons.capsule;
      if (n.contains('alat') || n.contains('peralatan'))
        return CupertinoIcons.hammer;
      return CupertinoIcons.tag;
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = _categories[i];
        final name = (c['name'] ?? 'Kategori').toString();
        final count = (c['count'] ?? 0) as int;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconFor(name), color: primaryBlue),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '$count produk',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            trailing: const Icon(
              CupertinoIcons.chevron_forward,
              color: Colors.black38,
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Nanti: filter produk kategori "$name"'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _reviewsTab() {
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Belum ada ulasan'),
            const SizedBox(height: 10),
            Text(
              _reviewCount > 0
                  ? 'rating ${_avgRating.toStringAsFixed(1)}/5'
                  : 'rating -',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = _reviews[i];
        final rating = (r['rating'] ?? 0) as int;
        final comment = (r['comment'] ?? '').toString();

        String name = 'User';
        String avatar = '';

        final user = r['user'];
        if (user is Map) {
          final fullName = (user['full_name'] ?? '').toString();
          final uname = (user['username'] ?? '').toString();
          name = fullName.isNotEmpty
              ? fullName
              : (uname.isNotEmpty ? uname : 'User');
          avatar = (user['profile_image_url'] ?? user['photo_url'] ?? '')
              .toString();
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: pillBg,
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.hardEdge,
                child: avatar.isNotEmpty
                    ? Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          CupertinoIcons.person_fill,
                          color: primaryBlue,
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.person_fill,
                        color: primaryBlue,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    _stars(rating.toDouble()),
                    const SizedBox(height: 8),
                    Text(
                      comment.isNotEmpty ? comment : '-',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
