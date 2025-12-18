import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/filter_data.dart';
import '../filter/filter_main_view.dart';
import 'Product/product_detail_view.dart';
import '../utils/image_helper.dart';

// Konstanta Warna Dasar
const Color primaryBlue = Color(0xFF2563FF);
const Color textSecondary = Color(0xFF8E99AF);

class CustomSearchDelegate extends SearchDelegate<String> {
  final List<String> popularSuggestions = ['Sepatu', 'Tas', 'Hoodie', 'Cardigan', 'Kemeja'];

  @override
  String get searchFieldLabel => 'Cari items dan brands';

  @override
  InputDecorationTheme get searchFieldDecorationTheme => InputDecorationTheme(
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        filled: true,
        fillColor: Colors.white,
        prefixIconColor: Colors.black,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey, width: 1.5),
        ),
      );


  @override
List<Widget> buildActions(BuildContext context) {
  return [];
}

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.black),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? popularSuggestions
        : popularSuggestions.where((p) => p.toLowerCase().contains(query.toLowerCase())).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        if (query.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Populer',
              style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
        ...suggestions.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item, style: const TextStyle(fontSize: 16, color: Colors.black)),
              onTap: () {
                query = item;
                showResults(context);
              },
            )),
      ],
    );
  }

FilterData _activeFilter = FilterData();

@override
Widget buildResults(BuildContext context) {
  return SearchResultsView(
    query: query,
    initialFilter: _activeFilter,
    onFilterChanged: (newFilter) {
      _activeFilter = newFilter; // UPDATE DISINI agar saat tombol filter dipencet lagi, data yang tadi masih ada
    },
  );
}


  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: searchFieldDecorationTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
    );
  }
}

class SearchResultsView extends StatefulWidget {
  final String query;
  final FilterData initialFilter; // Terima filter awal
  final Function(FilterData) onFilterChanged; // Callback untuk simpan filter

  const SearchResultsView({
    super.key, 
    required this.query, 
    required this.initialFilter,
    required this.onFilterChanged,
  });

  @override
  State<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<SearchResultsView> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  FilterData _activeFilter = FilterData();


  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter; // Ambil data dari delegate
    _fetchSearchResults();
  }

  // Menghitung semua kategori yang aktif untuk ditampilkan di badge tombol
 int _countActiveFilters() {
  int count = 0;

  count += _activeFilter.selectedCategories.length;
  count += _activeFilter.selectedBrands.length;
  count += _activeFilter.selectedSizes.length;
  count += _activeFilter.selectedColors.length;
  count += _activeFilter.selectedConditions.length;

  if (_activeFilter.minPrice > 0 ||
      _activeFilter.maxPrice < 100000000) {
    count++;
  }

  if (_activeFilter.selectedSortBy.isNotEmpty) count++;

  return count;
}


  Future<void> _fetchSearchResults({FilterData? filter}) async {
  if (!mounted) return;

  final f = filter ?? _activeFilter;
  setState(() => _isLoading = true);

  try {
    var query = _client
        .from('products')
        .select('*')
        .or(
          'name.ilike.%${widget.query}%,'
          'category.ilike.%${widget.query}%,'
          'brand.ilike.%${widget.query}%'
        )
        .gte('price', f.minPrice)
        .lte('price', f.maxPrice);

    // BRAND
    if (f.selectedBrands.isNotEmpty) {
      query = query.inFilter('brand', f.selectedBrands);
    }

    // CATEGORY
    if (f.selectedCategories.isNotEmpty) {
      query = query.inFilter('category', f.selectedCategories);
    }

    // SIZE
    if (f.selectedSizes.isNotEmpty) {
      query = query.inFilter('size', f.selectedSizes);
    }

    //  COLOR
    if (f.selectedColors.isNotEmpty) {
      query = query.inFilter('color', f.selectedColors);
    }

    //  CONDITION
    if (f.selectedConditions.isNotEmpty) {
      query = query.inFilter('condition', f.selectedConditions);
    }

    //  SORT
    if (f.selectedSortBy.isNotEmpty) {
        final sort = f.selectedSortBy.first;

        if (sort == 'Harga: termurah dulu') {
          query.order('price', ascending: true);
        } else if (sort == 'Harga: tertinggi dulu') {
          query..order('price', ascending: false);
        } else if (sort == 'Terbaru') {
          query..order('created_at', ascending: false);
        }
      }

    final response = await query;
    final processed = await ImageHelper.processImages(response as List);

    if (mounted) {
      setState(() {
        _products = List<Map<String, dynamic>>.from(processed);
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint('Fetch Error: $e');
    if (mounted) setState(() => _isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading 
        ? const Center(child: CupertinoActivityIndicator(color: primaryBlue))
        : Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildGrid()),
            ],
          ),
      bottomNavigationBar: const _CommonBottomNavBar(),
    );
  }

  Widget _buildHeader() {
  final int filterCount = _countActiveFilters();

 return Container(
  width: double.infinity,
  alignment: Alignment.centerLeft, // 🔥 TAMBAH INI
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, // 🔥 SUDAH BENAR
    children: [

        // 1. Teks Hasil Pencarian
        Text(
          '${widget.query} (${_products.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        
        const SizedBox(height: 12),

        // 2. Tombol Filter
        OutlinedButton(
        onPressed: () async {
          // Kirim _activeFilter yang sedang aktif saat ini
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FilterMainView(initialFilter: _activeFilter),
            ),
          );

          // Jika user menekan "Show Results"
        if (result != null && result is FilterData && mounted) {
        setState(() {
          _activeFilter = result; 
        });

        widget.onFilterChanged(result);
        _fetchSearchResults(filter: _activeFilter); 
      }
    },
        // ... rest of style
        child: Row(
          mainAxisSize: MainAxisSize.min, 
          children: [
            const Icon(Icons.tune, size: 18),
            const SizedBox(width: 8),
            const Text('Filter', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 16)),
            
            // LOGIKA ANGKA FILTER (Akan otomatis update karena setState di atas)
            if (_countActiveFilters() > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Color(0xFFE0E0E0), shape: BoxShape.circle),
                child: Text(
                  '${_countActiveFilters()}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
     ],
    ),
  );
}

  Widget _buildGrid() {
    if (_products.isEmpty) return const Center(child: Text('Produk tidak ditemukan'));
    
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) => _ProductGridCard(data: _products[index]),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProductGridCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // Ambil URL gambar dari key 'image_url' (hasil proses ImageHelper)
    final String imageUrl = data['image_url'] ?? '';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailView(productId: data['id'].toString()),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: imageUrl.isNotEmpty 
                  ? Image.network(
                      imageUrl, // <-- PAKAI INI
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
              ),
            ),

            // BAGIAN KETERANGAN:
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. NAMA PRODUK
                  Text(
                    data['name'] ?? 'No Name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // 2. HARGA
                  Text(
                    'Rp ${data['price'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                    style: const TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 3. BRAND
                  Text(
                      data['brand'] ?? 'No Brand',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13, 
                        color: Colors.black87
                        ),
                    ),

                  // 4. SIZE
                  Text(
                    data['size']?.toString() ?? '-',
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13, 
                      color: Colors.black87
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}

class _CommonBottomNavBar extends StatelessWidget {
  const _CommonBottomNavBar();
  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
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
      unselectedItemColor: primaryBlue,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      backgroundColor: Colors.white,
    );
  }
}
