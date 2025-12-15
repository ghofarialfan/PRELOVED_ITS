// lib/services/product_detail_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductDetailPage extends StatefulWidget {
  final String productId;

  const ProductDetailPage({Key? key, required this.productId}) : super(key: key);

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  static const String _storageBucketName = 'photo_url_pp'; 
  
  bool _loading = true;
  Map<String, dynamic>? _product;
  String _selectedSize = '';
  bool _isFavorite = false;
  List<Map<String, dynamic>> _productImages = [];
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  // Fungsi untuk mendapatkan URL publik dari path Storage
  String _getPublicImageUrl(String path) {
    // Jika ternyata path sudah berupa URL lengkap (URL Supabase lama/Unsplash),
    // kita asumsikan itu adalah URL yang gagal. Namun, karena data sudah dikoreksi,
    // ini hanya untuk jaga-jaga.
    if (path.startsWith('http')) {
      return path;
    }
    // Jika path relatif (products/file.jpg)
    return Supabase.instance.client.storage
        .from(_storageBucketName)
        .getPublicUrl(path);
  }

  Future<void> _loadProduct() async {
    try {
      final client = Supabase.instance.client;
      
      final response = await client
          .from('products')
          .select('''
            *,
            product_images(id, image_url, order_index, is_featured)
          ''')
          .eq('id', widget.productId)
          .single();

      final reviewsResponse = await client
          .from('product_reviews')
          .select('rating')
          .eq('product_id', widget.productId);

      double averageRating = 0.0;
      int totalReviews = 0;
      
      if (reviewsResponse.isNotEmpty) {
        totalReviews = reviewsResponse.length;
        final totalRating = reviewsResponse.fold<int>(
          0, 
          (sum, review) => sum + (review['rating'] as int)
        );
        averageRating = totalRating / totalReviews;
      }

      // --- LOGIKA PERBAIKAN GAMBAR DI DETAIL PAGE ---
      List<Map<String, dynamic>> images = [];
      if (response['product_images'] != null) {
        images = List<Map<String, dynamic>>.from(response['product_images']);
        images.sort((a, b) => 
          (a['order_index'] ?? 0).compareTo(b['order_index'] ?? 0)
        );
        
        // MENGUBAH PATH RELATIF (products/file.jpg) MENJADI URL LENGKAP
        images = images.map((image) {
          final imageUrlPath = image['image_url'] as String;
          // Perbarui image_url di dalam list menjadi URL publik
          image['image_url'] = _getPublicImageUrl(imageUrlPath);
          return image;
        }).toList();
      }
      // -----------------------------------------------

      setState(() {
        _product = response;
        _product!['average_rating'] = averageRating;
        _product!['total_reviews'] = totalReviews;
        _productImages = images;
        
        if (_product != null && _product!['size'] != null) {
          _selectedSize = _product!['size'].toString();
        }
        
        _loading = false;
      });

      _checkFavorite();
      _incrementViewCount();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading product: $e')),
        );
      }
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      final client = Supabase.instance.client;
      final currentCount = _product!['view_count'] ?? 0;
      
      await client
          .from('products')
          .update({'view_count': currentCount + 1})
          .eq('id', widget.productId);
    } catch (e) {
      // Silent fail untuk view count
    }
  }

  Future<void> _checkFavorite() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      
      if (user != null) {
        final response = await client
            .from('favorites')
            .select()
            .eq('user_id', user.id)
            .eq('product_id', widget.productId)
            .maybeSingle();

        setState(() {
          _isFavorite = response != null;
        });
      }
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan login terlebih dahulu')),
        );
        return;
      }

      if (_isFavorite) {
        await client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', widget.productId);
        
        setState(() => _isFavorite = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dihapus dari favorit')),
        );
      } else {
        await client.from('favorites').insert({
          'user_id': user.id,
          'product_id': widget.productId,
        });
        
        setState(() => _isFavorite = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ditambahkan ke favorit')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _addToCart() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan login terlebih dahulu')),
        );
        return;
      }

      final existing = await client
          .from('carts')
          .select()
          .eq('user_id', user.id)
          .eq('product_id', widget.productId)
          .maybeSingle();

      if (existing != null) {
        await client
            .from('carts')
            .update({
              'quantity': existing['quantity'] + 1,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing['id']);
      } else {
        await client.from('carts').insert({
          'user_id': user.id,
          'product_id': widget.productId,
          'quantity': 1,
          'selected_size': _selectedSize,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil ditambahkan ke keranjang'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _buyNow() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Pembelian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Produk: ${_product!['name']}'),
            if (_selectedSize.isNotEmpty)
              Text('Ukuran: $_selectedSize'),
            Text('Harga: Rp ${_formatPrice(_product!['discount_price'] ?? _product!['price'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to checkout
            },
            child: const Text('Checkout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Produk'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detail Produk'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: Text('Produk tidak ditemukan')),
      );
    }

    // Tentukan harga yang ditampilkan
    final displayPrice = _product!['discount_price'] ?? _product!['price'];
    final hasDiscount = _product!['discount_price'] != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.black,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.black),
                  onPressed: () {},
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.grey[100],
                child: _productImages.isNotEmpty
                    ? Stack(
                        children: [
                          PageView.builder(
                            itemCount: _productImages.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              // URL yang sudah diubah oleh _getPublicImageUrl()
                              return Image.network(
                                _productImages[index]['image_url'],
                                fit: BoxFit.cover,
                                // Mencegah cache Chrome menyimpan URL yang salah
                                headers: const {'Cache-Control': 'no-cache'}, 
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 100,
                                      color: Colors.grey[400],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          // Image indicator
                          if (_productImages.length > 1)
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _productImages.length,
                                  (index) => Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentImageIndex == index
                                          ? Colors.blue
                                          : Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Center(
                        child: Icon(
                          Icons.image,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                      ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _product!['category'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _product!['condition'] == 'new' 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _product!['condition'] == 'new' ? 'Baru' : 'Bekas',
                          style: TextStyle(
                            fontSize: 12,
                            color: _product!['condition'] == 'new'
                                ? Colors.green[700]
                                : Colors.orange[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    _product!['name'] ?? 'Nama Produk',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  
                  if (_product!['brand'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Brand: ${_product!['brand']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 22),
                      const SizedBox(width: 4),
                      Text(
                        '${(_product!['average_rating'] ?? 0.0).toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/5.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_product!['total_reviews'] ?? 0} ulasan)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.inventory_2_outlined, 
                        size: 18, 
                        color: Colors.grey[600]
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Stok: ${_product!['stock'] ?? 0}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.1),
                          Colors.blue.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDiscount) ...[
                          Row(
                            children: [
                              Text(
                                'Rp ${_formatPrice(_product!['price'])}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_calculateDiscount()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            const Text(
                              'Harga:',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Rp ${_formatPrice(displayPrice)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_product!['size'] != null && 
                      _product!['size'].toString().isNotEmpty) ...[
                    const Text(
                      'Ukuran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        border: Border.all(color: Colors.blue, width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _product!['size'].toString(),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const Text(
                    'Deskripsi Produk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _product!['description'] ?? 'Tidak ada deskripsi',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _addToCart,
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.blue),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _product!['stock'] > 0 ? _buyNow : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _product!['stock'] > 0 ? 'Beli Sekarang' : 'Stok Habis',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateDiscount() {
    if (_product!['discount_price'] == null) return 0;
    final price = _product!['price'] as num;
    final discountPrice = _product!['discount_price'] as num;
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
