import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product/product_detail_view.dart';
import 'services/products_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _featured = [];
  List<Map<String, dynamic>> _newProducts = [];
  List<Map<String, dynamic>> _forYou = [];
  bool _loading = true;
  String? _name;

  String? _selectedCategory;
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _loadingFiltered = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isFeaturedExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _withPublicImageAsync(List<dynamic> rows) async {
    final client = Supabase.instance.client;
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
      if (coverIdByProduct.isNotEmpty) {
        final coverIds = coverIdByProduct.values.toList();
        final coverRows = await client
            .from('product_images')
            .select('id, image_url')
            .filter('id', 'in', '(${coverIds.map((e) => '"$e"').join(",")})');
        final byId = <String, String>{};
        for (final row in (coverRows as List<dynamic>)) {
          final id = (row as Map)['id'].toString();
          final path = (row['image_url'] ?? '').toString();
          if (id.isNotEmpty && path.isNotEmpty) byId[id] = path;
        }
        coverIdByProduct.forEach((pid, cid) {
          final path = byId[cid];
          if (path != null && path.isNotEmpty) grouped[pid] = path;
        });
      }
      final missing = ids.where((pid) => !grouped.containsKey(pid));
      for (final pid in missing) {
        final img = await client
            .from('product_images')
            .select('image_url, order_index')
            .eq('product_id', pid)
            .order('order_index', ascending: true)
            .limit(1)
            .maybeSingle();
        final path = (img?['image_url'] ?? '').toString();
        if (path.isNotEmpty) grouped[pid] = path;
      }
      for (final m in maps) {
        final pid = (m['id'] ?? '').toString();
        var path = grouped[pid] ?? '';
        if (path.isNotEmpty) {
          if (path.startsWith('http')) {
            m['image_url'] = path;
          } else {
            var normalized = path.trim();
            normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
            if (!normalized.contains('/')) {
              normalized = 'products/$normalized';
            }
            m['image_url'] = client.storage.from('products').getPublicUrl(normalized);
          }
        }
      }
    } catch (e) {
      debugPrint('Attach images error: $e');
    }
    return maps;
  }

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('elektronik') || lower.contains('gadget') || lower.contains('hp')) {
      return CupertinoIcons.device_phone_portrait;
    }
    if (lower.contains('fashion pria') || lower.contains('pakaian pria') || lower.contains('baju pria')) {
      return Icons.man;
    }
    if (lower.contains('fashion wanita') || lower.contains('pakaian wanita') || lower.contains('baju wanita')) {
      return Icons.woman;
    }
    if (lower.contains('pakaian') || lower.contains('baju') || lower.contains('fashion') || lower.contains('kaos') || lower.contains('kemeja')) {
      return CupertinoIcons.tag;
    }
    if (lower.contains('buku') || lower.contains('literasi')) {
      return CupertinoIcons.book;
    }
    if (lower.contains('aksesoris')) {
      return CupertinoIcons.eyeglasses;
    }
    if (lower.contains('jam')) {
      return CupertinoIcons.clock;
    }
    if (lower.contains('sepatu') || lower.contains('sandal')) {
      return Icons.do_not_step; // Ikon sepatu
    }
    if (lower.contains('tas') || lower.contains('dompet')) {
      return CupertinoIcons.bag;
    }
    if (lower.contains('makanan') || lower.contains('minuman')) {
      return CupertinoIcons.cart;
    }
    if (lower.contains('rumah') || lower.contains('furniture') || lower.contains('mebel')) {
      return CupertinoIcons.house;
    }
    if (lower.contains('kesehatan') || lower.contains('kecantikan')) {
      return CupertinoIcons.heart;
    }
    if (lower.contains('olahraga')) {
      return CupertinoIcons.sportscourt;
    }
    return CupertinoIcons.square_grid_2x2;
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      List<Map<String, dynamic>> catsList = [];
      List<dynamic> featuredRows = const [];
      List<dynamic> newsRows = const [];
      List<dynamic> forYouRows = const [];

      try {
        // Ambil kategori dari tabel products agar sesuai dengan data yang ada
        final productCats = await client.from('products').select('category');
        final uniqueCategories = <String>{};
        final catsListBuilder = <Map<String, dynamic>>[];
        
        for (final item in productCats) {
            final catName = (item['category'] ?? '').toString();
            // Filter kategori kosong atau null
            if (catName.isNotEmpty && catName != 'null' && !uniqueCategories.contains(catName)) {
                uniqueCategories.add(catName);
                catsListBuilder.add({'name': catName});
            }
        }
        // Urutkan kategori secara alfabetis
        catsListBuilder.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        
        catsList = catsListBuilder;
      } catch (e) {
        debugPrint('Error fetching categories from products: $e');
      }

      try {
        featuredRows = await client
            .from('products')
            .select('*')
            .limit(20);
      } catch (e) {
        debugPrint('Load featured error: $e');
      }

      try {
        newsRows = await client
            .from('products')
            .select('*')
            .limit(20);
      } catch (e) {
        debugPrint('Load new products error: $e');
      }

      try {
        forYouRows = await client
            .from('products')
            .select('*')
            .limit(20);
      } catch (e) {
        debugPrint('Load for you error: $e');
      }

      Future<List<Map<String, dynamic>>> withPublicImageAsync(List<dynamic> rows) async {
        return _withPublicImageAsync(rows);
      }

      final featuredMapped = await withPublicImageAsync(featuredRows);
      final newsMapped = await withPublicImageAsync(newsRows);
      final forYouMapped = await withPublicImageAsync(forYouRows);
      debugPrint('Featured image_url sample: ${featuredMapped.take(3).map((m) => m['image_url']).toList()}');
      debugPrint('News image_url sample: ${newsMapped.take(3).map((m) => m['image_url']).toList()}');

      setState(() {
        _categories = catsList;
        _featured = featuredMapped;
        _newProducts = newsMapped.where((m) => (m['is_new'] ?? false) == true).take(6).toList();
        forYouMapped.sort((a, b) => ((b['view_count'] ?? 0) as int).compareTo((a['view_count'] ?? 0) as int));
        _forYou = forYouMapped.take(12).toList();
        _loading = false;
      });
      debugPrint('Loaded categories: ${_categories.length}, featured: ${_featured.length}, new: ${_newProducts.length}, forYou: ${_forYou.length}');
    } catch (e) {
      debugPrint('Supabase load error: ${e.toString()}');
      setState(() {
        _categories = [];
        _featured = [];
        _newProducts = [];
        _forYou = [];
        _loading = false;
      });
    }
  }

  Future<void> _onCategoryTap(String category) async {
    _searchController.clear();
    setState(() {
      _isSearching = false;
    });

    if (_selectedCategory == category) {
      setState(() {
        _selectedCategory = null;
        _filteredProducts = [];
      });
      return;
    }

    setState(() {
      _selectedCategory = category;
      _loadingFiltered = true;
    });

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('products')
          .select('*')
          .eq('category', category);

      final mapped = await _withPublicImageAsync(res as List<dynamic>);

      if (mounted) {
        setState(() {
          _filteredProducts = mapped;
          _loadingFiltered = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading category products: $e');
      if (mounted) {
        setState(() {
          _filteredProducts = [];
          _loadingFiltered = false;
        });
      }
    }
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredProducts = [];
        _selectedCategory = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _selectedCategory = null;
      _loadingFiltered = true;
    });

    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('products')
          .select('*')
          .ilike('name', '%$query%');

      final mapped = await _withPublicImageAsync(res as List<dynamic>);

      if (mounted) {
        setState(() {
          _filteredProducts = mapped;
          _loadingFiltered = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching products: $e');
      if (mounted) {
        setState(() {
          _filteredProducts = [];
          _loadingFiltered = false;
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final resId = await client.from('users').select().eq('id', user.id).limit(1);
      var list = (resId as List<dynamic>);
      if (list.isNotEmpty) {
        final m = list.first as Map<String, dynamic>;
        final name = (m['full_name'] ?? '').toString();
        setState(() {
          _name = name.isNotEmpty ? name : null;
        });
      }
    } catch (_) {}
  }

  String get _displayName {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final meta = user?.userMetadata ?? {};
      if (_name != null && _name!.isNotEmpty) return _name!;
      final fullName = (meta['full_name'] ?? meta['name'] ?? '').toString();
      if (fullName.isNotEmpty) return fullName;
      final email = user?.email ?? '';
      if (email.isNotEmpty) return email.split('@').first;
    } catch (_) {}
    return 'Pengguna';
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    // Updated colors to match the image style
    const textDark = Color(0xFF1F2937); 
    const textGrey = Color(0xFF6B7280); 
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Increased padding
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selamat Datang, $_displayName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onSubmitted: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari',
                hintStyle: const TextStyle(color: textGrey),
                prefixIcon: const Icon(CupertinoIcons.search, color: primaryBlue),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_isSearching) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hasil Pencarian "${_searchController.text}"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              if (_loadingFiltered)
                 const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_filteredProducts.isEmpty)
                 const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Tidak ada produk ditemukan', style: TextStyle(color: Color(0xFF8E99AF)))),
                 )
              else
                 GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 2, 
                       childAspectRatio: 0.72, 
                       mainAxisSpacing: 10, 
                       crossAxisSpacing: 10
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, i) {
                       final p = _filteredProducts[i];
                       return _ProductCard(
                          title: (p['name'] ?? p['title'] ?? '').toString(),
                          price: (p['prize'] ?? p['price'] ?? 0) as num,
                          imageUrl: (p['image_url'] ?? '').toString(),
                          onTap: () {
                            final id = (p['id'] ?? '').toString();
                            if (id.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailView(productId: id),
                                ),
                              );
                            }
                          },
                       );
                    },
                 ),
            ]
            else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProductsPage()),
                    );
                  },
                  child: const Text('Semua Produk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563FF))),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: GridView.count(
                crossAxisCount: 2,
                scrollDirection: Axis.horizontal,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
                children: _categories.map((c) {
                  final name = (c['name'] ?? c['title'] ?? 'Kategori').toString();
                  return _CategoryTile(
                    name: name,
                    icon: _getCategoryIcon(name),
                    isSelected: _selectedCategory == name,
                    onTap: () => _onCategoryTap(name),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedCategory != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Produk $_selectedCategory', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              if (_loadingFiltered)
                 const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_filteredProducts.isEmpty)
                 const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Tidak ada produk untuk kategori ini', style: TextStyle(color: Color(0xFF8E99AF)))),
                 )
              else
                 GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 2, 
                       childAspectRatio: 0.72, 
                       mainAxisSpacing: 10, 
                       crossAxisSpacing: 10
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, i) {
                       final p = _filteredProducts[i];
                       return _ProductCard(
                          title: (p['name'] ?? p['title'] ?? '').toString(),
                          price: (p['prize'] ?? p['price'] ?? 0) as num,
                          imageUrl: (p['image_url'] ?? '').toString(),
                          onTap: () {
                            final id = (p['id'] ?? '').toString();
                            if (id.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailView(productId: id),
                                ),
                              );
                            }
                          },
                       );
                    },
                 ),
            ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Produk Unggulan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isFeaturedExpanded = !_isFeaturedExpanded;
                    });
                  },
                  child: Text(_isFeaturedExpanded ? 'Tutup' : 'Lihat Semua', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2563FF))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_featured.isEmpty && _newProducts.isEmpty && _forYou.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Belum ada data produk atau koneksi Supabase belum dikonfigurasi',
                      style: TextStyle(color: Color(0xFF8E99AF))),
                ),
              ),
            // Show Featured products
            if (_isFeaturedExpanded)
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  childAspectRatio: 0.72, 
                  mainAxisSpacing: 10, 
                  crossAxisSpacing: 10
                ),
                itemCount: (_featured.isNotEmpty ? _featured : _newProducts).length,
                itemBuilder: (context, i) {
                  final p = (_featured.isNotEmpty ? _featured : _newProducts)[i];
                  return _ProductCard(
                    title: (p['name'] ?? p['title'] ?? '').toString(),
                    price: (p['prize'] ?? p['price'] ?? 0) as num,
                    imageUrl: (p['image_url'] ?? '').toString(),
                    onTap: () {
                      final id = (p['id'] ?? '').toString();
                      if (id.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailView(productId: id),
                          ),
                        );
                      }
                    },
                  );
                },
              )
            else
              _ProductList(items: _featured.isNotEmpty ? _featured : _newProducts),
            const SizedBox(height: 24),
            Row(
              children: const [
                Text('Hanya Untukmu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                SizedBox(width: 6),
                Icon(CupertinoIcons.star_fill, color: primaryBlue, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                 crossAxisCount: 2, 
                 childAspectRatio: 0.65, // Adjusted for taller cards
                 mainAxisSpacing: 12, 
                 crossAxisSpacing: 12
              ),
              itemCount: _forYou.length,
              itemBuilder: (context, i) {
                final p = _forYou[i];
                return _ProductCard(
                  title: (p['name'] ?? p['title'] ?? '').toString(),
                  price: (p['prize'] ?? p['price'] ?? 0) as num,
                  imageUrl: (p['image_url'] ?? 'https://picsum.photos/seed/for$i/240/240').toString(),
                  onTap: () {
                    final id = (p['id'] ?? '').toString();
                    if (id.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailView(productId: id),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            ],
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 1) {
            Navigator.pushNamed(context, '/favorites');
            return;
          }
          if (i == 2) {
            Navigator.pushNamed(context, '/orders');
            return;
          }
          if (i == 3) {
            Navigator.pushNamed(context, '/cart');
            return;
          }
          if (i == 4) {
            Navigator.pushNamed(context, '/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.bag), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), label: ''),
        ],
        selectedItemColor: Colors.black,
        unselectedItemColor: const Color(0xFF2563FF),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isSelected;

  const _CategoryTile({
    required this.name,
    required this.icon,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2563FF) : const Color(0xFFF2F6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF2563FF), size: 32),
          ),
          const SizedBox(height: 4),
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ProductList({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260, // Increased height to accommodate taller cards
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4), // Add padding for shadow
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = items[i];
          return _ProductCard(
            title: (p['name'] ?? p['title'] ?? '').toString(),
            price: (p['prize'] ?? p['price'] ?? 0) as num,
            imageUrl: (p['image_url'] ?? 'https://picsum.photos/seed/p$i/240/160').toString(),
            onTap: () {
              final id = (p['id'] ?? '').toString();
              if (id.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailView(productId: id),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String title;
  final num price;
  final String imageUrl;
  final VoidCallback? onTap;
  const _ProductCard({required this.title, required this.price, required this.imageUrl, this.onTap});

  String _formatPrice(num price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    // Updated colors to match the image style
    const textDark = Color(0xFF1F2937); // Darker for prices
    const textGrey = Color(0xFF6B7280); // Grey for titles
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              child: Image.network(
                imageUrl,
                height: 160, // Taller image as per visual reference
                width: 160,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(height: 160, width: 160, color: const Color(0xFFE9F0FF)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textGrey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text('Rp ${_formatPrice(price)}', style: const TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
