// lib/services/products_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart'; 
import '../product/product_detail_view.dart';

class ProductsPage extends StatefulWidget {
  final String? category;

  const ProductsPage({super.key, this.category});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  List<Product> _products = []; 
  List<Product> _filteredProducts = [];
  bool _loading = true;
  String _selectedCategory = 'Semua';
  
  static const String _storageBucketName = 'products';
  
  final List<String> _categories = [
    'Semua', 'Elektronik', 'Fashion Pria', 'Fashion Wanita', 
    'Sepatu', 'Furniture', 'Olahraga', 'Buku',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _selectedCategory = widget.category!;
      if (!_categories.contains(_selectedCategory) && _selectedCategory != 'Semua') {
        _categories.add(_selectedCategory);
      }
    }
    _loadProducts();
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

  Future<void> _loadProducts() async {
    try {
      if (mounted) {
        setState(() => _loading = true);
      }
      
      final client = Supabase.instance.client;
      
      final response = await client
          .from('products')
          .select('*')
          .order('created_at', ascending: false);

      final mappedProducts = await _withPublicImageAsync(response as List<dynamic>);

      final productsList = <Product>[];
      
      for (var item in mappedProducts) {
        final productMap = Map<String, dynamic>.from(item);
        
        // Get average rating
        try {
          final reviewsResponse = await client
              .from('product_reviews')
              .select('rating')
              .eq('product_id', productMap['id']);

          if (reviewsResponse.isNotEmpty) {
            final totalRating = reviewsResponse.fold<int>(
              0, 
              (sum, review) => sum + (review['rating'] as int? ?? 0)
            );
            productMap['average_rating'] = totalRating / reviewsResponse.length;
            productMap['total_reviews'] = reviewsResponse.length; 
          } else {
            productMap['average_rating'] = 0.0;
            productMap['total_reviews'] = 0;
          }
        } catch (e) {
          debugPrint('Error getting reviews: $e');
          productMap['average_rating'] = 0.0;
          productMap['total_reviews'] = 0;
        }
        
        try {
          productsList.add(Product.fromMap(productMap));
        } catch (e) {
          debugPrint('Error creating product from map: $e');
        }
      }

      if (mounted) {
        setState(() {
          _products = productsList;
          _filterProducts();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) {
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
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

  Widget _buildProductCard(Product product) {
    const textDark = Color(0xFF1F2937);
    const textGrey = Color(0xFF6B7280);
    const primaryBlue = Color(0xFF2563FF);

    final displayPrice = product.discountPrice ?? product.price;
    final hasDiscount = product.discountPrice != null;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailView(productId: product.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9F0FF),
                    borderRadius: BorderRadius.only(
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
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.broken_image, 
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Icon(
                              Icons.image,
                              size: 40,
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
                        horizontal: 6,
                        vertical: 2,
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
                      horizontal: 6,
                      vertical: 2,
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
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.category, 
                        style: TextStyle(
                          fontSize: 10,
                          color: primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Product Name
                    Text(
                      product.name, 
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textGrey,
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
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '(${product.totalReviews ?? 0})', 
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
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
                          fontSize: 10,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    Text(
                      'Rp ${_formatPrice(displayPrice)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textDark,
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

  int _calculateDiscount(Product product) {
    if (product.discountPrice == null) return 0; 
    final price = product.price; 
    final discountPrice = product.discountPrice!; 
    return (((price - discountPrice) / price) * 100).round();
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final priceInt = price is int ? price : int.tryParse(price.toString()) ?? 0;
    return priceInt.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
