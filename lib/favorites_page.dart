import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product/product_detail_view.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _debugInfo;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _debugInfo = 'Starting load...';
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
         setState(() {
           _items = [];
           _loading = false;
           _debugInfo = 'User not logged in';
         });
         return;
      }

      debugPrint('Fetching favorites for user: ${user.id}');
      // 1. Fetch favorites only
      final favResponse = await client
          .from('favorites')
          .select('product_id')
          .eq('user_id', user.id);
      
      debugPrint('Fav Response: $favResponse');

      final favList = (favResponse as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      
      if (favList.isEmpty) {
         setState(() {
           _items = [];
           _loading = false;
           _debugInfo = 'No favorites found in DB';
         });
         return;
      }

      final productIds = favList
          .map((e) => e['product_id'])
          .where((id) => id != null)
          .map((id) => id.toString())
          .toSet()
          .toList();
      
      debugPrint('Product IDs: $productIds');

      if (productIds.isEmpty) {
        setState(() {
           _items = [];
           _loading = false;
           _debugInfo = 'Favorites found but no valid product IDs';
         });
         return;
      }

      // 2. Fetch products manually
      List<Map<String, dynamic>> products = [];
      try {
        final filterVal = '(${productIds.map((e) => '"$e"').join(",")})';
        final productsResponse = await client
            .from('products')
            .select('*')
            .filter('id', 'in', filterVal);
        
        products = (productsResponse as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      } catch (e) {
        debugPrint('Error fetching products: $e');
        setState(() {
          _debugInfo = 'Error fetching products: $e';
        });
        // Continue to show what we have (maybe nothing)
      }

      final List<Map<String, dynamic>> combinedItems = [];
      final productMap = {for (var p in products) (p['id'] ?? '').toString(): p};

      for (final fav in favList) {
        final pid = (fav['product_id'] ?? '').toString();
        final p = productMap[pid];
        if (p != null) {
          final newItem = Map<String, dynamic>.from(p);
          newItem['product_id'] = pid;
          combinedItems.add(newItem);
        } else {
           debugPrint('Product $pid not found in products table');
        }
      }

      // 3. Attach images
      if (combinedItems.isNotEmpty) {
        await _attachImages(client, combinedItems);
      }

      setState(() {
        _items = combinedItems;
        _loading = false;
        _debugInfo = combinedItems.isEmpty 
            ? 'Found ${favList.length} favorites, but 0 matching products.\nIDs: $productIds'
            : null; // Clear debug info if successful
      });

    } catch (e, stack) {
      debugPrint('Error loading favorites: $e\n$stack');
      setState(() {
        _loading = false;
        _debugInfo = 'Error: $e';
      });
    }
  }

  Future<void> _attachImages(SupabaseClient client, List<Map<String, dynamic>> items) async {
    try {
      final productIds = items.map((m) => m['product_id'].toString()).toSet().toList();
      if (productIds.isEmpty) return;

      // Fetch images for these products
      // Strategy: 
      // 1. Check if 'product_image_id' is present and fetch those.
      // 2. Or fetch first image for each product from product_images.
      
      // Let's just fetch the first image for each product to be safe and simple
      final imagesResponse = await client
          .from('product_images')
          .select('product_id, image_url, order_index')
          .filter('product_id', 'in', '(${productIds.map((e) => '"$e"').join(",")})')
          .order('order_index', ascending: true);

      final imagesMap = <String, String>{}; // productId -> imageUrl
      
      for (final img in (imagesResponse as List<dynamic>)) {
        final pid = img['product_id'].toString();
        // Since we ordered by order_index, the first one we see is the best candidate 
        // if we haven't seen one yet.
        if (!imagesMap.containsKey(pid)) {
             imagesMap[pid] = (img['image_url'] ?? '').toString();
        }
      }

      // Normalize URLs
      for (final item in items) {
        final pid = item['product_id'].toString();
        var path = imagesMap[pid];
        
        // Fallback: check if product has 'product_image_id' and we missed it? 
        // The above query gets all images for these products, so if it exists, we got it.
        // Unless product_image_id points to an image that is NOT linked via product_id? (Unlikely)
        
        if (path != null && path.isNotEmpty) {
           if (path.startsWith('http')) {
             item['image_url'] = path;
           } else {
             var normalized = path.trim();
             normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
             if (!normalized.contains('/')) {
               normalized = 'products/$normalized';
             }
             item['image_url'] = client.storage.from('products').getPublicUrl(normalized);
           }
        }
      }
    } catch (e) {
      debugPrint('Error attaching images: $e');
    }
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final pid = (m['product_id'] ?? '').toString();
      
      if (pid.isNotEmpty) {
        await client.from('favorites').delete().eq('user_id', user.id).eq('product_id', pid);
      } 
      
      await _load();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorit')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              )
            : _items.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(CupertinoIcons.heart, color: Colors.blue, size: 48),
                          const SizedBox(height: 16),
                          const Text('Belum ada favorit', style: TextStyle(color: Colors.grey)),
                          if (_debugInfo != null)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(
                                _debugInfo!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ElevatedButton(
                            onPressed: _load,
                            child: const Text('Refresh'),
                          )
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _items.length + (_debugInfo != null ? 1 : 0),
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      if (_debugInfo != null && i == 0) {
                         return Container(
                           color: Colors.yellow[100],
                           padding: const EdgeInsets.all(8),
                           child: SelectableText(_debugInfo!, style: const TextStyle(fontSize: 10)),
                         );
                      }
                      
                      try {
                        final index = _debugInfo != null ? i - 1 : i;
                        if (index < 0 || index >= _items.length) return const SizedBox();

                      final m = _items[index];
                      final title = (m['title'] ?? m['name'] ?? m['product_name'] ?? '').toString();
                      final imageUrl = (m['image_url'] ?? m['product_image_url'] ?? '').toString();
                      
                      num parseNum(dynamic v) {
                        if (v is num) return v;
                        if (v is String) return num.tryParse(v) ?? 0;
                        return 0;
                      }

                      final price = parseNum(m['discount_price'] ?? m['sale_price'] ?? m['price'] ?? m['prize']);
                      final oldPrice = parseNum(m['price'] ?? m['prize']);
                final color = (m['color'] ?? m['variant_color'] ?? '').toString();
                final size = (m['size'] ?? m['variant_size'] ?? '').toString();
                return GestureDetector(
                  onTap: () {
                    final pid = (m['product_id'] ?? '').toString();
                    if (pid.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailView(productId: pid)));
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4)),
                    ]),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                        child: Image.network(
                          imageUrl.isNotEmpty ? imageUrl : 'https://picsum.photos/seed/fav$i/120/120',
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(width: 110, height: 110, color: const Color(0xFFE9F0FF)),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8E99AF))),
                              const SizedBox(height: 6),
                          Row(
                            children: [
                              if (oldPrice > price)
                                Text('Rp ${oldPrice.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF8E99AF), decoration: TextDecoration.lineThrough)),
                              if (oldPrice > price) const SizedBox(width: 6),
                              Text('Rp ${price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF2563FF), fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _Tag(text: color.isEmpty ? 'Pink' : color),
                              const SizedBox(width: 6),
                              _Tag(text: size.isEmpty ? 'M' : size),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 110,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _remove(m),
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, right: 12),
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFFF4D4F), width: 2)),
                            child: const Icon(CupertinoIcons.delete, color: Color(0xFFFF4D4F), size: 18),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(bottom: 12, right: 12),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: const Color(0xFFE9F0FF), borderRadius: BorderRadius.circular(20)),
                          child: IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang')));
                            },
                            icon: const Icon(CupertinoIcons.cart_badge_plus, color: Color(0xFF2563FF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                    ],
                  ),
                ),
              );
            } catch (e) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Error rendering item $i: $e', style: const TextStyle(color: Colors.red)),
              );
            }
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushNamed(context, '/home');
            return;
          }
          if (i == 2) {
            Navigator.pushNamed(context, '/orders');
            return;
          }
          if (i == 4) {
            Navigator.pushNamed(context, '/profile');
            return;
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

class _Tag extends StatelessWidget {
  final String text;
  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFE9F0FF), borderRadius: BorderRadius.circular(16)),
      child: Text(text, style: const TextStyle(color: primaryBlue)),
    );
  }
}

