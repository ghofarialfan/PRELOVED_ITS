import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() {
          _items = const [];
          _loading = false;
        });
        return;
      }
      final rows = await client.from('favorites').select().eq('user_id', user.id);
      setState(() {
        _items = (rows as List<dynamic>).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _items = const [];
        _loading = false;
      });
    }
  }

  Future<void> _remove(Map<String, dynamic> m) async {
    try {
      final client = Supabase.instance.client;
      final id = (m['id'] ?? '').toString();
      if (id.isNotEmpty) {
        await client.from('favorites').delete().eq('id', id);
      } else {
        final user = client.auth.currentUser;
        final productId = (m['product_id'] ?? '').toString();
        if (user != null && productId.isNotEmpty) {
          await client.from('favorites').delete().eq('user_id', user.id).eq('product_id', productId);
        }
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
    const primaryBlue = Color(0xFF2563FF);
    const blueSoft = Color(0xFFE9F0FF);
    const textSecondary = Color(0xFF8E99AF);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.pop(context)),
        title: const Text('Favorit'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(CupertinoIcons.heart, color: primaryBlue, size: 32),
                      SizedBox(height: 8),
                      Text('Belum ada favorit', style: TextStyle(color: textSecondary)),
                    ],
                  ),
                )
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                final m = _items[i];
                final title = (m['title'] ?? m['name'] ?? m['product_name'] ?? '').toString();
                final imageUrl = (m['image_url'] ?? m['product_image_url'] ?? '').toString();
                final price = (m['discount_price'] ?? m['sale_price'] ?? m['price'] ?? m['prize'] ?? 0) as num;
                final oldPrice = (m['price'] ?? m['prize'] ?? 0) as num;
                final color = (m['color'] ?? m['variant_color'] ?? '').toString();
                final size = (m['size'] ?? m['variant_size'] ?? '').toString();
                return Container(
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
                          errorBuilder: (c, e, s) => Container(width: 110, height: 110, color: blueSoft),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textSecondary)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (oldPrice > price)
                                    Text('Rp ${oldPrice.toStringAsFixed(0)}', style: const TextStyle(color: textSecondary, decoration: TextDecoration.lineThrough)),
                                  if (oldPrice > price) const SizedBox(width: 6),
                                  Text('Rp ${price.toStringAsFixed(0)}', style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w700)),
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
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _remove(m),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFFF4D4F), width: 2)),
                              child: const Icon(CupertinoIcons.delete, color: Color(0xFFFF4D4F), size: 18),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            margin: const EdgeInsets.only(bottom: 12, right: 12),
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: blueSoft, borderRadius: BorderRadius.circular(20)),
                            child: IconButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang')));
                              },
                              icon: const Icon(CupertinoIcons.cart_badge_plus, color: primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
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

