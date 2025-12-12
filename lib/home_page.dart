import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final cats = await client.from('categories').select().limit(12);
      final featured = await client
          .from('products')
          .select()
          .order('updated_at', ascending: false)
          .limit(6);
      final news = await client
          .from('products')
          .select()
          .eq('is_new', true)
          .order('created_at', ascending: false)
          .limit(6);
      final forYou = await client
          .from('products')
          .select()
          .order('view_count', ascending: false);
      setState(() {
        _categories = (cats as List<dynamic>).cast<Map<String, dynamic>>();
        _featured = (featured as List<dynamic>).cast<Map<String, dynamic>>();
        _newProducts = (news as List<dynamic>).cast<Map<String, dynamic>>();
        _forYou = (forYou as List<dynamic>).cast<Map<String, dynamic>>();
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Selamat Datang, Andra', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: primaryBlue, width: 2)),
                  child: const Icon(CupertinoIcons.camera, color: primaryBlue, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: 'Cari',
                prefixIcon: const Icon(CupertinoIcons.search, color: primaryBlue),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                'https://picsum.photos/seed/banner/800/300',
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(height: 160, color: const Color(0xFFE9F0FF)),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Kategori', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Lihat Semua', style: TextStyle(color: primaryBlue)),
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
                children: _categories.map((c) => _CategoryTile(name: (c['name'] ?? c['title'] ?? 'Kategori').toString(), imageUrl: (c['image_url'] ?? 'https://picsum.photos/seed/cat/100/100').toString())).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Produk Unggulan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_featured.isEmpty && _newProducts.isEmpty && _forYou.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Belum ada data produk atau koneksi Supabase belum dikonfigurasi',
                      style: TextStyle(color: Color(0xFF8E99AF))),
                ),
              ),
            _ProductList(items: _featured),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Barang Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Lihat Semua', style: TextStyle(color: primaryBlue)),
              ],
            ),
            const SizedBox(height: 8),
            _ProductList(items: _newProducts),
            const SizedBox(height: 16),
            Row(
              children: const [
                Text('Hanya Untukmu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(width: 6),
                Icon(CupertinoIcons.star_fill, color: primaryBlue, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemCount: _forYou.length,
              itemBuilder: (context, i) {
                final p = _forYou[i];
                return _ProductCard(
                  title: (p['name'] ?? p['title'] ?? '').toString(),
                  price: (p['prize'] ?? p['price'] ?? 0) as num,
                  imageUrl: (p['image_url'] ?? 'https://picsum.photos/seed/for$i/240/240').toString(),
                );
              },
            ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
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
  final String imageUrl;
  const _CategoryTile({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(width: 64, height: 64, color: const Color(0xFFE9F0FF)),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ProductList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ProductList({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = items[i];
          return _ProductCard(
            title: (p['name'] ?? p['title'] ?? '').toString(),
            price: (p['prize'] ?? p['price'] ?? 0) as num,
            imageUrl: (p['image_url'] ?? 'https://picsum.photos/seed/p$i/240/160').toString(),
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
  const _ProductCard({required this.title, required this.price, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    const textSecondary = Color(0xFF8E99AF);
    return Container(
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
              height: 110,
              width: 160,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(height: 110, width: 160, color: const Color(0xFFE9F0FF)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: textSecondary)),
                const SizedBox(height: 6),
                Text('Rp ${price.toStringAsFixed(0)}', style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
