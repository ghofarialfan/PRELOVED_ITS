import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductDetailView extends StatefulWidget {
  final String productId;

  const ProductDetailView({Key? key, required this.productId}) : super(key: key);

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  static const String _storageBucketName = 'photo_url_pp';

  bool _loading = true;
  Map<String, dynamic>? _product;
  bool _isFavorite = false;
  List<Map<String, dynamic>> _productImages = [];
  int _currentImageIndex = 0;
  String _selectedSize = '';

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  String _getPublicImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return Supabase.instance.client.storage.from(_storageBucketName).getPublicUrl(path);
  }

  Future<void> _loadProduct() async {
    try {
      final client = Supabase.instance.client;
      var resp = await client
          .from('products')
          .select('*, product_images(id, image_url, order_index, is_featured)')
          .eq('id', widget.productId)
          .maybeSingle();

      debugPrint('[_loadProduct] initial lookup productId=${widget.productId} response=$resp');

      // Fallback: if not found, try numeric id (some tables use integer ids)
      if (resp == null) {
        final tryInt = int.tryParse(widget.productId);
        if (tryInt != null) {
          final resp2 = await client
              .from('products')
              .select('*, product_images(id, image_url, order_index, is_featured)')
              .eq('id', tryInt)
              .maybeSingle();
          debugPrint('[_loadProduct] fallback lookup int id=$tryInt response=$resp2');
          if (resp2 != null) resp = resp2;
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
      
      // PERBAIKAN: Process image URLs dengan null safety
      try {
        final imagesRaw = data['product_images'];
        if (imagesRaw != null && imagesRaw is List && imagesRaw.isNotEmpty) {
          final imagesList = imagesRaw
              .map((img) {
                if (img is! Map) return null;
                final mm = Map<String, dynamic>.from(img);
                final path = mm['image_url'] ?? mm['imageUrl'];
                if (path != null && path is String && !path.startsWith('http')) {
                  try {
                    mm['image_url'] = client.storage.from(_storageBucketName).getPublicUrl(path);
                  } catch (e) {
                    debugPrint('Error getting public URL: $e');
                  }
                }
                return mm;
              })
              .where((img) => img != null)
              .cast<Map<String, dynamic>>()
              .toList();
          
          imagesList.sort((a, b) => (a['order_index'] ?? 0).compareTo(b['order_index'] ?? 0));
          data['product_images'] = imagesList;
        }

        final mainPath = data['image_url'] ?? data['imageUrl'];
        if (mainPath != null && mainPath is String && !mainPath.startsWith('http')) {
          try {
            data['image_url'] = client.storage.from(_storageBucketName).getPublicUrl(mainPath);
          } catch (e) {
            debugPrint('Error getting main image URL: $e');
          }
        }
      } catch (e) {
        debugPrint('[_loadProduct] error converting image paths: $e');
      }

      // Get reviews
      final reviews = await client
          .from('product_reviews')
          .select('rating')
          .eq('product_id', widget.productId);

      double avg = 0.0;
      int total = 0;
      if (reviews.isNotEmpty) {
        total = reviews.length;
        final sum = reviews.fold<int>(0, (s, r) => s + ((r['rating'] as int?) ?? 0));
        avg = sum / total;
      }

      // Process final images list
      List<Map<String, dynamic>> images = [];
      final productImagesData = data['product_images'];
      if (productImagesData != null && productImagesData is List) {
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
      }

      if (mounted) {
        setState(() {
          _product = data;
          _product!['average_rating'] = avg;
          _product!['total_reviews'] = total;
          _productImages = images;
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
        return;
      }
      if (_isFavorite) {
        await client.from('favorites').delete().eq('user_id', user.id).eq('product_id', widget.productId);
        setState(() => _isFavorite = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dihapus dari favorit')));
      } else {
        await client.from('favorites').insert({'user_id': user.id, 'product_id': widget.productId});
        setState(() => _isFavorite = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ditambahkan ke favorit')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addToCart() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk ditambahkan ke keranjang'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nego terkirim')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(
                icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : Colors.black),
                onPressed: _toggleFavorite,
              ),
              IconButton(icon: const Icon(Icons.share), onPressed: () {}),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.grey[100],
                child: _productImages.isNotEmpty
                    ? Stack(
                        children: [
                          PageView.builder(
                            itemCount: _productImages.length,
                            onPageChanged: (i) => setState(() => _currentImageIndex = i),
                            itemBuilder: (context, index) {
                              return Image.network(
                                _productImages[index]['image_url'],
                                fit: BoxFit.cover,
                                headers: const {'Cache-Control': 'no-cache'},
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                                  );
                                },
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
                                      color: _currentImageIndex == index ? Colors.blue : Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : const Center(child: Icon(Icons.image, size: 100)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text((_product!['category'] ?? '').toString(), style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: _product!['condition'] == 'new' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(_product!['condition'] == 'new' ? 'Baru' : 'Bekas', style: TextStyle(fontSize: 12, color: _product!['condition'] == 'new' ? Colors.green[700] : Colors.orange[700], fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text((_product!['name'] ?? 'Nama Produk').toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3)),
                  if (_product!['brand'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Brand: ${_product!['brand']}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 22),
                      const SizedBox(width: 4),
                      Text('${(_product!['average_rating'] ?? 0.0).toStringAsFixed(1)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text('/5.0', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const SizedBox(width: 8),
                      Text('(${_product!['total_reviews'] ?? 0} ulasan)', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      const Spacer(),
                      Icon(Icons.inventory_2_outlined, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('Stok: ${_product!['stock'] ?? 0}', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.1), Colors.blue.withOpacity(0.05)]), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (hasDiscount) ...[
                        Row(children: [
                          Text('Rp ${_formatPrice(_product!['price'])}', style: TextStyle(fontSize: 16, color: Colors.grey[600], decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: Text('${_calculateDiscount()}%', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
                        ]),
                        const SizedBox(height: 8),
                      ],
                      Row(children: [
                        const Text('Harga:', style: TextStyle(fontSize: 16, color: Colors.black87)),
                        const SizedBox(width: 8),
                        Text('Rp ${_formatPrice(displayPrice)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  if (_product!['size'] != null && _product!['size'].toString().isNotEmpty) ...[
                    const Text('Ukuran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), border: Border.all(color: Colors.blue, width: 1), borderRadius: BorderRadius.circular(8)), child: Text(_product!['size'].toString(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 14))),
                    const SizedBox(height: 24),
                  ],
                  const Text('Deskripsi Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text((_product!['description'] ?? 'Tidak ada deskripsi').toString(), style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6), textAlign: TextAlign.justify),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, -3))]),
        child: SafeArea(
          child: Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _openNegotiate,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('Nego', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(12)),
              child: IconButton(onPressed: _addToCart, icon: const Icon(Icons.shopping_cart_outlined, color: Colors.blue), padding: const EdgeInsets.all(12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (_product!['stock'] ?? 0) > 0 ? _buyNow : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, disabledBackgroundColor: Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: Text(((_product!['stock'] ?? 0) > 0) ? 'Beli' : 'Stok Habis', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ]),
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
    return priceInt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }
}