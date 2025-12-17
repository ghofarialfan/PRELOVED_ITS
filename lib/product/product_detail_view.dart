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
    
    // DEBUG: Cek path aslinya
    debugPrint('[_getPublicImageUrl] Original Path: $path');
    
    // Jika tidak ada slash, kemungkinan besar ini ada di root bucket ATAU butuh folder 'products/'
    // Mari kita coba paksa tambah 'products/' karena biasanya file diupload ke folder tersebut.
    if (!normalized.contains('/')) {
       normalized = 'products/$normalized';
    }
    
    final url = Supabase.instance.client.storage.from(_storageBucketName).getPublicUrl(normalized);
    debugPrint('[_getPublicImageUrl] Generated URL: $url');
    return url;
  }

  Future<void> _loadProduct() async {
    try {
      final client = Supabase.instance.client;
      var resp = await client
          .from('products')
          .select('*, product_images(id, image_url, order_index)') // Langsung fetch product_images
          .eq('id', widget.productId)
          .maybeSingle();

      debugPrint('[_loadProduct] initial lookup productId=${widget.productId} response=$resp');

      if (resp == null) {
        // Fallback untuk legacy int ID jika diperlukan
        final tryInt = int.tryParse(widget.productId);
        if (tryInt != null) {
          final resp2 = await client
              .from('products')
              .select('*, product_images(id, image_url, order_index)')
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
      
      // Hapus logika manual parsing image_url di sini yang berlebihan
      // Kita akan proses semuanya di bagian _productImages construction

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

      // Proses Product Images
      List<Map<String, dynamic>> images = [];
      var productImagesData = data['product_images'];
      
      // FALLBACK: Jika join gagal (null) atau kosong, coba fetch manual dari tabel product_images
      if (productImagesData == null || (productImagesData is List && productImagesData.isEmpty)) {
        try {
          final manualImages = await client
              .from('product_images')
              .select('id, image_url, order_index')
              .eq('product_id', widget.productId)
              .order('order_index', ascending: true);
          if (manualImages != null && manualImages is List && manualImages.isNotEmpty) {
            productImagesData = manualImages;
            debugPrint('[_loadProduct] Fetched images manually: ${manualImages.length} images');
          }
        } catch (e) {
          debugPrint('[_loadProduct] Manual fetch images failed: $e');
        }
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
        // Fallback jika tidak ada product_images, gunakan image_url dari tabel products
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
                                  errorBuilder: (context, error, stackTrace) {
                                    debugPrint('Image load error: $error');
                                    return Container(
                                      color: Colors.grey[200],
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.broken_image, size: 32, color: Colors.red),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Error: $error',
                                            style: const TextStyle(fontSize: 10, color: Colors.red),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _productImages[index]['image_url'],
                                            style: const TextStyle(fontSize: 8, color: Colors.black),
                                            textAlign: TextAlign.center,
                                            maxLines: 4,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
                                      color: _currentImageIndex == index ? Colors.blue : Colors.white.withValues(alpha: 0.5),
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
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text((_product!['category'] ?? '').toString(), style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: _product!['condition'] == 'new' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: Text(_product!['condition'] == 'new' ? 'Baru' : 'Bekas', style: TextStyle(fontSize: 12, color: _product!['condition'] == 'new' ? Colors.green[700] : Colors.orange[700], fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _product!['name'] ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text((_product!['average_rating'] ?? 0.0).toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('(${_product!['total_reviews'] ?? 0})', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasDiscount) ...[
                    Text('Rp ${_formatPrice(_product!['price'])}', style: const TextStyle(fontSize: 14, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                    const SizedBox(height: 6),
                  ],
                  Text('Rp ${_formatPrice(displayPrice)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 12),
                  Text((_product!['description'] ?? '').toString(), style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _addToCart,
                          child: const Text('Tambah ke Keranjang'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _buyNow,
                        child: const Text('Beli Sekarang'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _openNegotiate,
                        child: const Text('Nego'),
                      ),
                    ],
                  ),
                ],
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
