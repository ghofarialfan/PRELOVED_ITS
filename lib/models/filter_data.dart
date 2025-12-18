// lib/models/filter_data.dart

class FilterData {
  List<String> selectedCategories;
  List<String> selectedSizes;
  List<String> selectedColors;
  List<String> selectedBrands;
  List<String> selectedConditions;
  List<String> selectedSortBy;
  num minPrice;
  num maxPrice;
  

  FilterData({
    this.selectedCategories = const [],
    this.selectedSizes = const [],
    this.selectedColors = const [],
    this.selectedBrands = const [],
    this.selectedConditions = const [],
    this.selectedSortBy = const [],
    this.minPrice = 0,
    this.maxPrice = 100000000, 
  });

  // Helper untuk mereset semua filter ke nilai default
  FilterData reset() {
    return FilterData();
  }
  
  // Helper untuk menampilkan rentang harga di halaman utama Filter
  String get priceRangeDisplay {
    // Jika masih default, tampilkan "Semua"
    if (minPrice <= 0 && maxPrice >= 100000000) return 'Semua';
    
    String formatPrice(num price) {
      return price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    }

    // Jika hanya Max yang diisi (Min masih 0)
    if (minPrice <= 0) return 'Di bawah Rp ${formatPrice(maxPrice)}';
    // Jika hanya Min yang diisi (Max masih default tinggi)
    if (maxPrice >= 100000000) return 'Di atas Rp ${formatPrice(minPrice)}';
    
    return 'Rp ${formatPrice(minPrice)} - Rp ${formatPrice(maxPrice)}';
  }

  // Helper untuk menampilkan status kategori di halaman utama Filter
  String get categoryDisplay => selectedCategories.isEmpty ? 'Semua' : selectedCategories.join(', ');
  String get sizeDisplay => selectedSizes.isEmpty ? 'Semua' : selectedSizes.join(', ');
  String get colorDisplay => selectedColors.isEmpty ? 'Semua' : selectedColors.join(', ');
  String get brandDisplay => selectedBrands.isEmpty ? 'Semua' : selectedBrands.join(', ');
  String get conditionDisplay => selectedConditions.isEmpty ? 'Semua' : selectedConditions.join(', ');
  String get sortByDisplay => selectedSortBy.isEmpty ? 'Semua' : selectedSortBy.first;
}