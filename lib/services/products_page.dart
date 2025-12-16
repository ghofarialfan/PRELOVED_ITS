// lib/services/products_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart'; 
import '../Product/product_detail_view.dart';

class ProductsPage extends StatefulWidget {
  final String? category;

  const ProductsPage({Key? key, this.category}) : super(key: key);

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> _products = []; 
  List<Product> _filteredProducts = [];
  bool _loading = true;
  String _selectedCategory = 'Semua';
  
  // PASTI JUGA NAMA BUCKET INI SUDAH BENAR
  static const String _storageBucketName = 'photo_url_pp'; 
  
  final List<String> _categories = [
    'Semua', 'Elektronik', 'Fashion Pria', 'Fashion Wanita', 
    'Sepatu', 'Furniture', 'Olahraga', 'Buku',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _selectedCategory = widget.category!;
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      if (mounted) { // Pengecekan aman
        setState(() => _loading = true);
      }
      
      final client = Supabase.instance.client;
      
      final response = await client
          .from('products')
          .select('''
            *,
            product_images!inner(image_url, is_featured, order_index)
          ''')
          .order('created_at', ascending: false);

      final productsList = <Product>[]; 
      
      for (var item in response) {
        final productMap = Map<String, dynamic>.from(item);
        
        // Proses Gambar: Mengubah Path Relatif menjadi URL Lengkap
        if (productMap['product_images'] != null) {
          final images = List<Map<String, dynamic>>.from(productMap['product_images']);
          images.sort((a, b) => (a['order_index'] ?? 0).compareTo(b['order_index'] ?? 0));
          final featuredImage = images.isNotEmpty ? images.first : {};
          final imagePath = featuredImage['image_url'] as String?;
          if (imagePath != null && imagePath.isNotEmpty) {
            final publicUrl = client.storage.from(_storageBucketName).getPublicUrl(imagePath);
            productMap['image_url'] = publicUrl;
          }
        }
        
        // Get average rating
        try {
          final reviewsResponse = await client
              .from('product_reviews')
              .select('rating')
              .eq('product_id', productMap['id']);

          if (reviewsResponse.isNotEmpty) {
            final totalRating = reviewsResponse.fold<int>(
              0, 
              (sum, review) => sum + (review['rating'] as int)
            );
            productMap['average_rating'] = totalRating / reviewsResponse.length;
            productMap['total_reviews'] = reviewsResponse.length; 
          } else {
            productMap['average_rating'] = 0.0;
            productMap['total_reviews'] = 0;
          }
        } catch (e) {
           productMap['average_rating'] = 0.0;
           productMap['total_reviews'] = 0;
        }
        
        productsList.add(Product.fromMap(productMap)); 
      }

      // KOREKSI UTAMA: Tambahkan if (mounted) untuk mencegah error klik
      if (mounted) {
        setState(() {
          _products = productsList;
          _filterProducts();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) { // Pengecekan aman
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  void _filterProducts() {
    if (_selectedCategory == 'Semua') {
      _filteredProducts = _products;
    } else {
      _filteredProducts = _products
          .where((product) => product.category == _selectedCategory)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Produk',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Implement filter
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter
          Container(
            height: 60,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                        _filterProducts();
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                    ),
                  ),
                );
              },
            ),
          ),

          // Products Grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada produk',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _buildProductCard(product);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // FUNGSI BUILD PRODUCT CARD
  Widget _buildProductCard(Product product) {
    final displayPrice = product.discountPrice ?? product.price;
    final hasDiscount = product.discountPrice != null;
    
    return GestureDetector(
      onTap: () {
        // KOREKSI UTAMA: Hapus .then((_) {_loadProducts();}) untuk mencegah error klik
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailView(productId: product.id),
          ),
        );
        // Hapus pemuatan produk yang menyebabkan setState() pada disposed widget
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Stack(
              children: [
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                        ? Image.network(
                            product.imageUrl!, 
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // Mencegah cache Chrome menyimpan URL yang salah
                            headers: const {'Cache-Control': 'no-cache'}, 
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.broken_image, 
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blue,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                ),
                
                // Discount badge
                if (hasDiscount)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_calculateDiscount(product)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Condition badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: product.condition == 'new' 
                          ? Colors.green
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.condition == 'new' ? 'Baru' : 'Bekas', 
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.category, 
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Product Name
                    Text(
                      product.name, 
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Rating
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.rating.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${product.totalReviews ?? 0})', 
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Price
                    if (hasDiscount) ...[
                      Text(
                        'Rp ${_formatPrice(product.price)}', 
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      'Rp ${_formatPrice(displayPrice)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FUNGSI BANTU MENGHITUNG DISKON
  int _calculateDiscount(Product product) {
    if (product.discountPrice == null) return 0; 
    final price = product.price; 
    final discountPrice = product.discountPrice!; 
    return (((price - discountPrice) / price) * 100).round();
  }

  // FUNGSI BANTU FORMAT HARGA
  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final priceInt = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return priceInt.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
