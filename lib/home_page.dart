import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _navIndex = 0;

  // Dummy data (nanti ganti dari Supabase)
  final List<_CategoryItem> categories = const [
    _CategoryItem(title: 'Kategori 1', count: 109, imageUrl: 'https://picsum.photos/seed/cat1/400/300'),
    _CategoryItem(title: 'Kategori 2', count: 530, imageUrl: 'https://picsum.photos/seed/cat2/400/300'),
    _CategoryItem(title: 'Kategori 3', count: 87, imageUrl: 'https://picsum.photos/seed/cat3/400/300'),
    _CategoryItem(title: 'Kategori 4', count: 218, imageUrl: 'https://picsum.photos/seed/cat4/400/300'),
    _CategoryItem(title: 'Kategori 5', count: 218, imageUrl: 'https://picsum.photos/seed/cat5/400/300'),
    _CategoryItem(title: 'Kategori 6', count: 218, imageUrl: 'https://picsum.photos/seed/cat6/400/300'),
  ];

  final List<_ProductItem> newProducts = const [
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/new1/500/500',
    ),
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/new2/500/500',
    ),
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/new3/500/500',
    ),
  ];

  final List<_ProductItem> recommended = const [
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/rec1/700/700',
    ),
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/rec2/700/700',
    ),
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/rec3/700/700',
    ),
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/rec4/700/700',
    ),
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/rec5/700/700',
    ),
    _ProductItem(
      title: 'Lorem ipsum dolor sit amet consectetur.',
      price: 50000,
      imageUrl: 'https://picsum.photos/seed/rec6/700/700',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            const SizedBox(height: 6),
            const Text(
              'Selamat Datang, Andra',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            // Search bar + camera
            _SearchBar(
              hintText: 'Cari',
              onCameraTap: () {},
              onChanged: (v) {},
            ),

            const SizedBox(height: 14),

            // Banner
            _BannerCard(
              imageUrl: 'https://picsum.photos/seed/banner/900/400',
              onSellTap: () {},
            ),

            const SizedBox(height: 18),

            // Kategori header
            _SectionHeader(
              title: 'Kategori',
              actionText: 'Lihat Semua',
              onActionTap: () {},
            ),
            const SizedBox(height: 10),

            // Categories grid (2 columns)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15,
              ),
              itemBuilder: (context, i) {
                final c = categories[i];
                return _CategoryCard(
                  title: c.title,
                  count: c.count,
                  imageUrl: c.imageUrl,
                  onTap: () {},
                );
              },
            ),

            const SizedBox(height: 18),

            // Produk Unggulan (avatars horizontal)
            const Text(
              'Produk Unggulan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  return CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage('https://picsum.photos/seed/feat$i/200/200'),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            // Barang Baru (horizontal cards)
            _SectionHeader(
              title: 'Barang Baru',
              actionText: 'Lihat Semua',
              onActionTap: () {},
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: newProducts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final p = newProducts[i];
                  return _SmallProductCard(
                    title: p.title,
                    price: p.price,
                    imageUrl: p.imageUrl,
                    onTap: () {},
                  );
                },
              ),
            ),

            const SizedBox(height: 18),

            // Hanya Untukmu (grid 2 kolom)
            const Row(
              children: [
                Text(
                  'Hanya Untukmu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 6),
                Icon(Icons.star, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recommended.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, i) {
                final p = recommended[i];
                return _BigProductCard(
                  title: p.title,
                  price: p.price,
                  imageUrl: p.imageUrl,
                  onTap: () {},
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),

      // Bottom Nav
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Colors.black,
        unselectedItemColor: const Color(0xFF2563FF),
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.bag), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), label: ''),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final String hintText;
  final VoidCallback onCameraTap;
  final ValueChanged<String> onChanged;
  const _SearchBar({
    required this.hintText,
    required this.onCameraTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2563FF), width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(CupertinoIcons.search, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                isDense: true,
                hintStyle: const TextStyle(color: Colors.black45),
              ),
            ),
          ),
          IconButton(
            onPressed: onCameraTap,
            icon: const Icon(CupertinoIcons.camera, color: Color(0xFF2563FF)),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onSellTap;
  const _BannerCard({required this.imageUrl, required this.onSellTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: Image.network(imageUrl, fit: BoxFit.cover),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onSellTap,
              child: const Text('Mulai Berjualan'),
            ),
          )
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onActionTap;
  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const Spacer(),
        InkWell(
          onTap: onActionTap,
          child: Row(
            children: [
              Text(actionText, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFF2563FF),
                child: Icon(CupertinoIcons.chevron_forward, size: 14, color: Colors.white),
              )
            ],
          ),
        )
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final int count;
  final String imageUrl;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.count,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F0FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallProductCard extends StatelessWidget {
  final String title;
  final int price;
  final String imageUrl;
  final VoidCallback onTap;

  const _SmallProductCard({
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.onTap,
  });

  String get _priceText => 'Rp ${price.toString().replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Text(_priceText, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigProductCard extends StatelessWidget {
  final String title;
  final int price;
  final String imageUrl;
  final VoidCallback onTap;

  const _BigProductCard({
    required this.title,
    required this.price,
    required this.imageUrl,
    required this.onTap,
  });

  String get _priceText => 'Rp ${price.toString().replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 8),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(_priceText, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem {
  final String title;
  final int count;
  final String imageUrl;
  const _CategoryItem({required this.title, required this.count, required this.imageUrl});
}

class _ProductItem {
  final String title;
  final int price;
  final String imageUrl;
  const _ProductItem({required this.title, required this.price, required this.imageUrl});
}
