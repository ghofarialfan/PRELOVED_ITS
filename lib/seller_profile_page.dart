import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../product/product_detail_view.dart';
import '../chat_page.dart';

class SellerProfilePage extends StatefulWidget {
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

  /// ✅ Helper public image URL yang aman
  /// - kalau sudah http -> pakai langsung
  /// - buang leading '/'
  /// - kalau belum ada folder -> tambahkan 'products/'
  String _publicImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;

    var normalized = path.trim();
    normalized = normalized.replaceFirst(RegExp(r'^/+'), '');

    if (!normalized.contains('/')) {
      normalized = 'products/$normalized';
    }

    return _client.storage.from('products').getPublicUrl(normalized);
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('elektronik') ||
        lower.contains('gadget') ||
        lower.contains('hp')) {
      return CupertinoIcons.device_phone_portrait;
    }
    if (lower.contains('fashion pria') || lower.contains('pakaian pria')) {
      return Icons.man;
    }
    if (lower.contains('fashion wanita') || lower.contains('pakaian wanita')) {
      return Icons.woman;
    }
    if (lower.contains('pakaian') ||
        lower.contains('baju') ||
        lower.contains('fashion') ||
        lower.contains('kaos') ||
        lower.contains('kemeja')) {
      return CupertinoIcons.tag;
    }
    if (lower.contains('buku')) return CupertinoIcons.book;
    if (lower.contains('sepatu')) return Icons.do_not_step;
    if (lower.contains('tas')) return CupertinoIcons.bag;
    if (lower.contains('olahraga')) return CupertinoIcons.sportscourt;
    return CupertinoIcons.square_grid_2x2;
  }

  String _formatRupiah(num v) {
    return 'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
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

  /// chats.product_id NOT NULL -> pakai product pertama seller sebagai context chat
  Future<String?> _createOrGetChatRoom({required String productId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final existing = await _client
          .from('chats')
          .select('id')
          .eq('buyer_id', user.id)
          .eq('seller_id', widget.sellerId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existing != null) return existing['id'].toString();

      final inserted = await _client
          .from('chats')
          .insert({
            'buyer_id': user.id,
            'seller_id': widget.sellerId,
            'product_id': productId,
            'last_message': 'Mulai chat',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return inserted['id'].toString();
    } catch (e) {
      debugPrint('Chat error: $e');
      return null;
    }
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

      if (sellerRes == null) throw Exception('Seller tidak ditemukan.');

      final prodRes = await _client
          .from('products')
          .select(
            'id, name, price, discount_price, created_at, seller_id, category_id, category:categories(id,name)',
          )
          .eq('seller_id', widget.sellerId)
          .order('created_at', ascending: false);

      final products = (prodRes as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final productIds = products.map((p) => p['id'].toString()).toList();

      /// ✅ Bulk ambil cover image untuk grid produk seller
      final Map<String, String> coverByProduct = {};
      if (productIds.isNotEmpty) {
        final imgRes = await _client
            .from('product_images')
            .select('product_id, image_url, order_index, display_order')
            .inFilter('product_id', productIds)
            .order('display_order', ascending: true)
            .order('order_index', ascending: true);

        for (final row in (imgRes as List)) {
          final m = Map<String, dynamic>.from(row as Map);
          final pid = (m['product_id'] ?? '').toString();
          coverByProduct.putIfAbsent(
            pid,
            () => _publicImageUrl((m['image_url'] ?? '').toString()),
          );
        }
      }

      for (final p in products) {
        final pid = p['id'].toString();
        p['primary_image_url'] = coverByProduct[pid] ?? '';
      }

      /// Categories unique
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
      final categoriesList = catMap.values.toList()
        ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      /// Reviews
      double avg = 0;
      int count = 0;
      final List<Map<String, dynamic>> reviews = [];

      if (productIds.isNotEmpty) {
        final revRes = await _client
            .from('product_reviews')
            .select(
              'id, product_id, rating, comment, created_at, user:users(id, full_name, username, profile_image_url, photo_url)',
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
        _categories = categoriesList;
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
        backgroundColor: Colors.white,
        body: Center(child: Text('Error: $_error')),
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
                              _publicImageUrl(photoUrl),
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
                        onPressed: () async {
                          if (_products.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Seller belum punya produk'),
                              ),
                            );
                            return;
                          }

                          final productId = _products.first['id'].toString();
                          final productName = (_products.first['name'] ?? '')
                              .toString();

                          final chatId = await _createOrGetChatRoom(
                            productId: productId,
                          );
                          if (!context.mounted) return;

                          if (chatId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gagal membuka chat'),
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                chatId: chatId,
                                sellerId: widget.sellerId,
                                sellerName: sellerName,
                                sellerAvatarUrl: _publicImageUrl(photoUrl),
                                productId: productId,
                                productName: productName,
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailView(productId: p['id'].toString()),
            ),
          ),
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
                            width: double.infinity,
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
              child: Icon(_getCategoryIcon(name), color: primaryBlue),
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryProductsPage(
                  sellerId: widget.sellerId,
                  categoryName: name,
                  categoryId: c['id'].toString(),
                  publicImageUrl: _publicImageUrl,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _reviewsTab() {
    if (_reviews.isEmpty) {
      return const Center(child: Text('Belum ada ulasan'));
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
                        _publicImageUrl(avatar),
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

/// ✅ CategoryProductsPage: Stateful + bulk fetch cover images
class CategoryProductsPage extends StatefulWidget {
  final String sellerId;
  final String categoryName;
  final String categoryId;

  final String Function(String path) publicImageUrl;

  const CategoryProductsPage({
    super.key,
    required this.sellerId,
    required this.categoryName,
    required this.categoryId,
    required this.publicImageUrl,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  static const primaryBlue = Color(0xFF2563FF);
  static const pillBg = Color(0xFFE9F0FF);

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _items = [];
  final Map<String, String> _coverByProduct = {}; // product_id -> url

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _formatRupiah(num v) {
    return 'Rp ${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      // 1) Load products in category
      final res = await client
          .from('products')
          .select('id, name, price, discount_price')
          .eq('seller_id', widget.sellerId)
          .eq('category_id', widget.categoryId)
          .order('created_at', ascending: false);

      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final ids = list.map((e) => e['id'].toString()).toList();

      // 2) Bulk load cover images (order by display_order/order_index)
      _coverByProduct.clear();
      if (ids.isNotEmpty) {
        final imgRes = await client
            .from('product_images')
            .select('product_id, image_url, display_order, order_index')
            .inFilter('product_id', ids)
            .order('display_order', ascending: true)
            .order('order_index', ascending: true);

        for (final row in (imgRes as List)) {
          final m = Map<String, dynamic>.from(row as Map);
          final pid = (m['product_id'] ?? '').toString();
          _coverByProduct.putIfAbsent(
            pid,
            () => widget.publicImageUrl((m['image_url'] ?? '').toString()),
          );
        }
      }

      // 3) Attach primary_image_url to each product
      for (final p in list) {
        final pid = p['id'].toString();
        p['primary_image_url'] = _coverByProduct[pid] ?? '';
      }

      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(widget.categoryName),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _items.isEmpty
          ? const Center(child: Text('Tidak ada produk'))
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.78,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final p = _items[i];

                final name = (p['name'] ?? '').toString();
                final num price = (p['price'] ?? 0) as num;
                final num? discount = p['discount_price'] == null
                    ? null
                    : (p['discount_price'] as num);
                final num shown = (discount != null && discount > 0)
                    ? discount
                    : price;

                final img = (p['primary_image_url'] ?? '').toString();

                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetailView(productId: p['id'].toString()),
                    ),
                  ),
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
                                    width: double.infinity,
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
            ),
    );
  }
}
