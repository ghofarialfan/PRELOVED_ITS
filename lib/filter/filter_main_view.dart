// lib/filter/filter_main_view.dart

import 'package:flutter/material.dart';
import '../search_page.dart'; // Untuk primaryBlue
import '../models/filter_data.dart';
import 'filter_detail_page.dart';

class FilterMainView extends StatefulWidget {
  final FilterData initialFilter;

  // Constructor menerima FilterData dari SearchResultsView
  const FilterMainView({super.key, required this.initialFilter});

  @override
  State<FilterMainView> createState() => _FilterMainViewState();
}

class _FilterMainViewState extends State<FilterMainView> {
  late FilterData _currentFilter;

  // Data statis untuk opsi filter
  final _categoryOptions = ['Aksesoris', 'Buku', 'Elektronik','Furniture', 'Perawatan', 'Olahraga', 'Fashion Pria', 'Fashion Wanita'];
  final _sizeOptions = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '38', '39', '40', '41', '42', '43'];
  final _colorOptions = ['Hitam', 'Putih', 'Abu-abu', 'Coklat', 'Kuning', 'Merah', 'Biru', 'Hijau', 'Oren', 'Ungu', 'Pink'];
  final _brandOptions = ['Uniqlo', 'Adidas', 'Nike', 'H&M', 'Puma', 'Zara', 'Erigo', 'Yonex', 'Gramedia', 'Apple', 'Samsung'];
  final _conditionOptions = ['Baru', 'Ada cacat sedikit', 'Layak'];
  final _sortByOptions = ['Populer', 'Terbaru', 'Harga: termurah dulu', 'Harga: tertinggi dulu'];

  @override
  void initState() {
    super.initState();
    // Menggunakan copy dari initialFilter agar perubahan bisa di-reset
    _currentFilter = FilterData(
      selectedCategories: List.from(widget.initialFilter.selectedCategories),
      selectedSizes: List.from(widget.initialFilter.selectedSizes),
      selectedColors: List.from(widget.initialFilter.selectedColors),
      selectedBrands: List.from(widget.initialFilter.selectedBrands),
      selectedConditions: List.from(widget.initialFilter.selectedConditions),
      selectedSortBy: List.from(widget.initialFilter.selectedSortBy),
      minPrice: widget.initialFilter.minPrice,
      maxPrice: widget.initialFilter.maxPrice,
    );
  }
  
  // Fungsi untuk membuka halaman detail filter (Checklist/Sort By)
  void _navigateToDetail(
  String title, 
  List<String> options, 
  List<String> initialSelected, 
  Function(List<String>) onUpdate
) async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FilterDetailPage(
        title: title,
        options: options,
        initialSelected: initialSelected,
        currentFilter: _currentFilter,
      ),
    ),
  );

  // Pastikan result adalah List<String> sebelum diupdate
 if (result != null && result is List) {
    setState(() {
      onUpdate(List<String>.from(result)); 
    });
  }
}
  
  // Fungsi untuk membuka halaman detail Harga (Input Teks)
  void _navigateToPrice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilterDetailPage(
          title: 'Harga',
          currentFilter: _currentFilter,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _currentFilter.minPrice = result['min'] as num;
        _currentFilter.maxPrice = result['max'] as num;
      });
    }
  }


  // Mengembalikan filter yang dipilih ke SearchResultsView
  void _applyFilter() {
  debugPrint("Mengirim filter ke Search: ${_currentFilter.selectedBrands}");
  Navigator.pop(context, _currentFilter);
}
  

  // Mereset semua filter
  void _resetFilter() {
    setState(() {
      _currentFilter = FilterData().reset();
    });
  }

  @override
Widget build(BuildContext context) {
  const localPrimaryBlue = Color(0xFF2563FF); // Pastikan variabel warna tersedia

  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true, 
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Filter',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 22, 
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          child: OutlinedButton(
            onPressed: _resetFilter,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryBlue,
              side: const BorderSide(color: primaryBlue), 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text(
              'Riset',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // 1. Kategori
                _buildFilterTile(
                  title: 'Kategori',
                  value: _currentFilter.categoryDisplay,
                  onTap: () => _navigateToDetail('Kategori', _categoryOptions, _currentFilter.selectedCategories, (res) {
                    setState(() { _currentFilter.selectedCategories = res ?? []; });
                  }),
                ),
                // 2. Size
                _buildFilterTile(
                  title: 'Size',
                  value: _currentFilter.sizeDisplay,
                  onTap: () => _navigateToDetail('Size', _sizeOptions, _currentFilter.selectedSizes, (res) {
                    setState(() { _currentFilter.selectedSizes = res ?? []; });
                  }),
                ),
                // 3. Warna
                _buildFilterTile(
                  title: 'Warna',
                  value: _currentFilter.colorDisplay,
                  onTap: () => _navigateToDetail('Warna', _colorOptions, _currentFilter.selectedColors, (res) {
                    setState(() { _currentFilter.selectedColors = res ?? []; });
                  }),
                ),
                // 4. Brand
                _buildFilterTile(
                  title: 'Brand',
                  value: _currentFilter.brandDisplay,
                  onTap: () => _navigateToDetail('Brand', _brandOptions, _currentFilter.selectedBrands, (res) {
                    setState(() { _currentFilter.selectedBrands = res ?? []; });
                  }),
                ),
                //kondisi
                _buildFilterTile(
                  title: 'Kondisi',
                  value: _currentFilter.conditionDisplay,
                  onTap: () => _navigateToDetail('Kondisi', _conditionOptions, _currentFilter.selectedConditions, (res) {
                    setState(() { _currentFilter.selectedConditions = res ?? []; });
                  }),
                ),
                // 5. Harga (Menggunakan fungsi navigasi berbeda karena tipe return berbeda)
                _buildFilterTile(
                  title: 'Harga',
                  value: _currentFilter.priceRangeDisplay,
                  onTap: _navigateToPrice,
                ),
                // 6. Sort by (Menggunakan DetailPage, hanya perlu 1 pilihan)
                  _buildFilterTile(
                    title: 'Sort by',
                    // Pastikan memanggil .sortByDisplay, bukan .selectedSortBy atau .sortBy
                    value: _currentFilter.sortByDisplay, 
                    onTap: () => _navigateToDetail(
                      'Sort By', 
                      _sortByOptions, 
                      _currentFilter.selectedSortBy, 
                      (res) {
                        setState(() { 
                          _currentFilter.selectedSortBy = res ?? []; 
                        });
                      }
                    ),
                  ),
              ],
            ),
          ),
          // Tombol Show Results di Bawah
          Container(
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: ElevatedButton(
              // PASTIKAN MEMANGGIL _applyFilter 
              onPressed: _applyFilter, 
              style: ElevatedButton.styleFrom(
                backgroundColor: localPrimaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Show Results', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget untuk setiap baris filter
  Widget _buildFilterTile({required String title, required String value, required VoidCallback onTap}) {
    return Column(
      children: [
        ListTile(
          title: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}