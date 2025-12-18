import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductDetailView extends StatefulWidget {
  final String productId;

  const ProductDetailView({super.key, required this.productId});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  static const String _storageBucketName = 'products';

  bool _loading = true;
  Map<String, dynamic>? _product;
  bool _isFavorite = false;
  List<Map<String, dynamic>> _productImages = [];
  int _currentImageIndex = 0;
  String _selectedSize = '';

  Map<String, dynamic>? _seller;
  List<Map<String, dynamic>> _reviewsList = [];

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  String _getPublicImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    var normalized = path.trim();
    normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
    if (!normalized.contains('/')) {
       normalized = 'products/$normalized';
    }
    return Supabase.instance.client.storage.from(_storageBucketName).getPublicUrl(normalized);
  }

  Future<void> _loadProduct() async {
    try {
      final client = Supabase.instance.client;
      
      // 1. Fetch Product
      var resp = await client
          .from('products')
          .select('*, product_images(id, image_url, order_index)')
          .eq('id', widget.productId)
          .maybeSingle();

      if (resp == null) {
        final tryInt = int.tryParse(widget.productId);
        if (tryInt != null) {
          resp = await client
              .from('products')
              .select('*, product_images(id, image_url, order_index)')
              .eq('id', tryInt)
              .maybeSingle();
        }
      }

      if (resp == null) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Produk tidak ditemukan (id: ${widget.productId})'))
          );
        }
        return;
      }

      final data = Map<String, dynamic>.from(resp);

      // 2. Fetch Reviews (Detail)
      List<Map<String, dynamic>> reviews = [];
      try {
        final reviewsData = await client
            .from('product_reviews')
            .select('*, users(full_name, photo_url)')
            .eq('product_id', widget.productId)
            .order('created_at', ascending: false);
        
        if (reviewsData != null && reviewsData is List) {
          reviews = List<Map<String, dynamic>>.from(reviewsData);
        }
      } catch (e) {
        debugPrint('[_loadProduct] failed to load reviews: $e');
        // Fallback: try loading simple reviews without join if join failed
        try {
           final simpleReviews = await client
              .from('product_reviews')
              .select()
              .eq('product_id', widget.productId);
           if (simpleReviews != null && simpleReviews is List) {
             reviews = List<Map<String, dynamic>>.from(simpleReviews);
           }
        } catch (_) {}
      }

      double avg = 0.0;
      int total = reviews.length;
      if (total > 0) {
        final sum = reviews.fold<int>(0, (s, r) => s + ((r['rating'] as int?) ?? 0));
        avg = sum / total;
      }

      // 3. Fetch Seller
      Map<String, dynamic>? sellerData;
      final sellerId = data['seller_id'];
      if (sellerId != null) {
        try {
          final sellerResp = await client
              .from('users')
              .select('id, full_name, photo_url, avatar_url, username')
              .eq('id', sellerId)
              .maybeSingle();
          if (sellerResp != null) {
            sellerData = Map<String, dynamic>.from(sellerResp);
          }
        } catch (e) {
           debugPrint('[_loadProduct] failed to load seller: $e');
        }
      }

      // 4. Process Images
      List<Map<String, dynamic>> images = [];
      var productImagesData = data['product_images'];
      
      if (productImagesData == null || (productImagesData is List && productImagesData.isEmpty)) {
        try {
          final manualImages = await client
              .from('product_images')
              .select('id, image_url, order_index')
              .eq('product_id', widget.productId)
              .order('order_index', ascending: true);
          if (manualImages != null && manualImages is List && manualImages.isNotEmpty) {
            productImagesData = manualImages;
          }
        } catch (_) {}
      }

      if (productImagesData != null && productImagesData is List && productImagesData.isNotEmpty) {
        images = productImagesData
            .map((m) {
              if (m is! Map) return null;
              final mm = Map<String, dynamic>.from(m);
              final img = (mm['image_url'] ?? mm['imageUrl']) as String? ?? '';
              mm['image_url'] = _getPublicImageUrl(img);
              return mm;
            })
            .where((img) => img != null)
            .cast<Map<String, dynamic>>()
            .toList();
        images.sort((a, b) => (a['order_index'] ?? 0).compareTo(b['order_index'] ?? 0));
      } else {
        final mainImg = (data['image_url'] ?? data['imageUrl']) as String?;
        if (mainImg != null && mainImg.isNotEmpty) {
          images.add({
             'id': 'main',
             'image_url': _getPublicImageUrl(mainImg),
             'order_index': 0
          });
        }
      }

      if (mounted) {
        setState(() {
          _product = data;
          _product!['average_rating'] = avg;
          _product!['total_reviews'] = total;
          _productImages = images;
          _reviewsList = reviews;
          _seller = sellerData;
          if (_product!['size'] != null) {
            _selectedSize = _product!['size'].toString();
          }
          _loading = false;
        });

        _checkFavorite();
        _incrementViewCount();
      }
    } catch (e) {
      debugPrint('[_loadProduct] error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      final client = Supabase.instance.client;
      final current = _product!['view_count'] ?? 0;
      await client.from('products').update({'view_count': current + 1}).eq('id', widget.productId);
    } catch (_) {}
  }

  Future<void> _checkFavorite() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final res = await client
          .from('favorites')
          .select()
          .eq('user_id', user.id)
          .eq('product_id', widget.productId)
          .maybeSingle();
      if (mounted) {
        setState(() => _isFavorite = res != null);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
        return;
      }
      if (_isFavorite) {
        await client.from('favorites').delete().eq('user_id', user.id).eq('product_id', widget.productId);
        setState(() => _isFavorite = false);
        messenger.showSnackBar(const SnackBar(content: Text('Dihapus dari favorit')));
      } else {
        await client.from('favorites').insert({'user_id': user.id, 'product_id': widget.productId});
        setState(() => _isFavorite = true);
        messenger.showSnackBar(const SnackBar(content: Text('Ditambahkan ke favorit')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addToCart() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
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
            .update({'quantity': existing['quantity'] + 1, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', existing['id']);
      } else {
        await client.from('carts').insert({
          'user_id': user.id,
          'product_id': widget.productId,
          'quantity': 1,
          'selected_size': _selectedSize,
        });
      }
      messenger.showSnackBar(const SnackBar(content: Text('Produk ditambahkan ke keranjang'), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
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
            if (_selectedSize.isNotEmpty) Text('Ukuran: $_selectedSize'),
            Text('Harga: Rp ${_formatPrice(_product!['discount_price'] ?? _product!['price'])}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () { Navigator.pop(context); }, child: const Text('Checkout')),
        ],
      ),
    );
  }

  Future<String?> _createOrGetChat() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return null;
      final sellerId = _product!['seller_id'] as String?;
      if (sellerId == null) return null;
      final existing = await client
          .from('chats')
          .select('id')
          .eq('buyer_id', user.id)
          .eq('seller_id', sellerId)
          .eq('product_id', widget.productId)
          .maybeSingle();
      if (existing != null) return existing['id'] as String;
      final inserted = await client
          .from('chats')
          .insert({
            'buyer_id': user.id,
            'seller_id': sellerId,
            'product_id': widget.productId,
            'last_message': 'Mulai nego',
          })
          .select('id')
          .single();
      return inserted['id'] as String;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openNegotiate() async {
    final controller = TextEditingController();
    final original = _product!['discount_price'] ?? _product!['price'];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ajukan Nego', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Harga saat ini: Rp ${_formatPrice(original)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Masukkan harga tawaran', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final offered = int.tryParse(controller.text.replaceAll('.', '').replaceAll(',', ''));
                      if (offered == null || offered <= 0) return;
                      Navigator.pop(context);
                      await _submitOffer(offered);
                    },
                    child: const Text('Kirim Nego'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitOffer(int offeredPrice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
        return;
      }
      final chatId = await _createOrGetChat();
      final sellerId = _product!['seller_id'] as String?;
      final original = _product!['discount_price'] ?? _product!['price'];
      final offer = await client
          .from('nego_offers')
          .insert({
            'product_id': widget.productId,
            'buyer_id': user.id,
            'seller_id': sellerId,
            'original_price': original,
            'offered_price': offeredPrice,
            'status': 'pending',
            'chat_id': chatId,
          })
          .select('id')
          .single();
      if (chatId != null) {
        await client.from('chat_messages').insert({
          'chat_id': chatId,
          'sender_id': user.id,
          'message': 'Menawar Rp ${_formatPrice(offeredPrice)}',
          'message_type': 'offer',
          'offer_id': offer['id'],
        });
      }
      messenger.showSnackBar(const SnackBar(content: Text('Nego terkirim')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Detail Produk')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_product == null) {
      return Scaffold(appBar: AppBar(title: const Text('Detail Produk')), body: const Center(child: Text('Produk tidak ditemukan')));
    }
    
    final displayPrice = _product!['discount_price'] ?? _product!['price'];
    
    // Safety check for strings
    final productName = (_product!['name'] ?? '').toString();
    final productDesc = (_product!['description'] ?? '').toString();
    final productCondition = (_product!['condition'] ?? 'used').toString(); // 'new' or 'used'
    final productSize = (_product!['size'] ?? 'All Size').toString();
    final sellerName = (_seller?['full_name'] ?? _seller?['username'] ?? 'Penjual').toString();
    final sellerCity = 'Jakarta'; // Mock location as requested
    final sellerPhoto = (_seller?['photo_url'] ?? _seller?['avatar_url'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : Colors.black),
            onPressed: _toggleFavorite,
          ),
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
        ],
      ),
      body: Stack(
        children: [
          // Scrollable Content
          Positioned.fill(
            bottom: 80, // Space for bottom bar
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Image Carousel
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        PageView.builder(
                          itemCount: _productImages.isNotEmpty ? _productImages.length : 1,
                          onPageChanged: (i) => setState(() => _currentImageIndex = i),
                          itemBuilder: (context, index) {
                            if (_productImages.isEmpty) {
                              return Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 50));
                            }
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenImageViewer(
                                      imageUrls: _productImages.map((e) => e['image_url'] as String).toList(),
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },
                              child: Image.network(
                                _productImages[index]['image_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: Colors.grey[200]),
                              ),
                            );
                          },
                        ),
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
                                    color: _currentImageIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 2. Title & Price
                        Text(
                          productName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(productSize, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(width: 8),
                            Container(width: 1, height: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              productCondition == 'new' ? 'Baru' : 'Baik', // 'Baik' matches Figma 'Baik'
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rp${_formatPrice(displayPrice)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                        
                        const SizedBox(height: 24),

                        // 3. Description
                        Text(
                          productDesc,
                          style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'sehari yang lalu', // Static for now or calc from updated_at
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // 4. Seller Profile
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: sellerPhoto.isNotEmpty ? NetworkImage(_getPublicImageUrl(sellerPhoto)) : null,
                              child: sellerPhoto.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sellerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(sellerCity, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: const [
                                      Icon(Icons.star, size: 14, color: Colors.amber),
                                      Icon(Icons.star, size: 14, color: Colors.amber),
                                      Icon(Icons.star, size: 14, color: Colors.amber),
                                      Icon(Icons.star, size: 14, color: Colors.amber),
                                      Icon(Icons.star_half, size: 14, color: Colors.amber),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur Profil akan segera hadir')));
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.grey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Lihat profil', style: TextStyle(color: Colors.black)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await _createOrGetChat();
                                  if (context.mounted) {
                                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat room dibuat (cek menu chat)')));
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[600],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Pesan', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),

                        // 5. Reviews
                        const Text('Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Text(
                                  (_product!['average_rating'] ?? 0.0).toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: const [
                                    Icon(Icons.star, size: 16, color: Colors.amber),
                                  ],
                                ),
                                Text('${_product!['total_reviews']} reviews', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [5, 4, 3, 2, 1].map((star) {
                                  // Mock distribution for now or calculate if possible
                                  // For simplicity, just showing static progress bar style
                                  double percent = 0.0;
                                  if (_reviewsList.isNotEmpty) {
                                    final count = _reviewsList.where((r) => (r['rating'] as int) == star).length;
                                    percent = count / _reviewsList.length;
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Text('$star', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(2),
                                            child: LinearProgressIndicator(
                                              value: percent,
                                              backgroundColor: Colors.grey[200],
                                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                                              minHeight: 4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Review List
                        if (_reviewsList.isNotEmpty)
                           ..._reviewsList.take(3).map((review) {
                             final rUser = review['users'] as Map?;
                             final rName = rUser?['full_name'] ?? 'User';
                             final rPhoto = rUser?['photo_url'] ?? '';
                             final rRating = (review['rating'] as int?) ?? 0;
                             final rComment = (review['comment'] ?? '').toString();
                             // TODO: time ago
                             
                             return Padding(
                               padding: const EdgeInsets.only(bottom: 16),
                               child: Row(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   CircleAvatar(
                                     radius: 16,
                                     backgroundColor: Colors.grey[200],
                                     backgroundImage: rPhoto.isNotEmpty ? NetworkImage(_getPublicImageUrl(rPhoto)) : null,
                                     child: rPhoto.isEmpty ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
                                   ),
                                   const SizedBox(width: 12),
                                   Expanded(
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Row(
                                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                           children: [
                                             Text(rName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                             const Text('1 bulan yang lalu', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                           ],
                                         ),
                                         Row(
                                           children: List.generate(5, (i) => Icon(Icons.star, size: 12, color: i < rRating ? Colors.amber : Colors.grey[300])),
                                         ),
                                         const SizedBox(height: 4),
                                         Text(rComment, style: const TextStyle(fontSize: 12)),
                                       ],
                                     ),
                                   ),
                                 ],
                               ),
                             );
                           }).toList()
                        else
                          const Text('Belum ada ulasan.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sticky Bottom Buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _openNegotiate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF222222), // Dark grey/black
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Nego', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _addToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Keranjang', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _buyNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0055FF), // Blue
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Beli', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_currentIndex + 1} / ${widget.imageUrls.length}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return ZoomableImage(imageUrl: widget.imageUrls[index]);
        },
      ),
    );
  }
}

class ZoomableImage extends StatefulWidget {
  final String imageUrl;

  const ZoomableImage({super.key, required this.imageUrl});

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        _transformationController.value = _animation!.value;
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails!.localPosition;

    Matrix4 endMatrix;
    // Check if zoomed in (scale > 1)
    if (_transformationController.value.getMaxScaleOnAxis() > 1.05) {
      endMatrix = Matrix4.identity();
    } else {
      const double scale = 2.5;
      final x = -position.dx * (scale - 1);
      final y = -position.dy * (scale - 1);
      endMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(scale);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurveTween(curve: Curves.easeInOut).animate(_animationController));

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, color: Colors.white, size: 64);
            },
          ),
        ),
      ),
    );
  }
}
