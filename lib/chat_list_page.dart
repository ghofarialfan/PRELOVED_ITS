import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _chats = [];

  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Listen to changes in 'chats' table
    _subscription = client
        .channel('public:chats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (payload) {
            // Simple approach: reload all chats on any change to 'chats' table
            // Ideally we check if payload involves current user
            _loadChats();
          },
        )
        .subscribe();
  }

  Future<void> _loadChats() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }

      // Ambil chat dimana user sebagai buyer atau seller
      final response = await client
          .from('chats')
          .select('''
            *,
            product:products(name, price, discount_price, product_images(image_url)),
            buyer:users!buyer_id(full_name, username, photo_url),
            seller:users!seller_id(full_name, username, photo_url)
          ''')
          .or('buyer_id.eq.${user.id},seller_id.eq.${user.id}')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading chats: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getDisplayImage(Map<String, dynamic> chat) {
    // Coba ambil gambar produk
    try {
      final product = chat['product'];
      if (product != null && product['product_images'] != null) {
        final images = product['product_images'] as List;
        if (images.isNotEmpty) {
          final img = images.first['image_url'];
          if (img != null) {
            return _getPublicUrl(img.toString());
          }
        }
      }
    } catch (_) {}
    return "https://i.imgur.com/BoN9kdC.png"; // Fallback
  }

  String _getPublicUrl(String path) {
    if (path.startsWith('http')) return path;
    var normalized = path.trim().replaceFirst(RegExp(r'^/+'), '');
    if (!normalized.contains('/')) normalized = 'products/$normalized';
    return Supabase.instance.client.storage
        .from('products')
        .getPublicUrl(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pesan"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChats,
              child: _chats.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 300),
                        Center(child: Text("Belum ada pesan")),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _chats.length,
                      itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final isBuyer = currentUser?.id == chat['buyer_id'];

                    // Kalau saya buyer -> tampilkan info seller
                    // Kalau saya seller -> tampilkan info buyer
                    final otherUser = isBuyer ? chat['seller'] : chat['buyer'];
                    final otherName = (otherUser?['full_name'] ??
                            otherUser?['username'] ??
                            'User')
                        .toString();
                    
                    final productName =
                        (chat['product']?['name'] ?? 'Produk').toString();
                    final lastMessage =
                        (chat['last_message'] ?? '').toString();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            NetworkImage(_getDisplayImage(chat)),
                      ),
                      title: Text(
                        otherName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              productId: (chat['product_id'] ?? '').toString(),
                              productName: productName,
                              // Di list chat mungkin kita tidak tau offerPrice terakhir 
                              // kecuali kita query nego_offers.
                              // Untuk sekarang kirim "0" atau ambil dari chat context jika ada.
                              // Tapi ChatPage butuh offerPrice untuk init state.
                              // Idealnya ChatPage handle logic kalau offerPrice null/kosong.
                              offerPrice: "0", 
                              sellerName: otherName,
                              sellerAvatar: otherUser?['photo_url']?.toString(), // Ambil dari otherUser['photo_url']
                              chatId: (chat['id'] ?? '').toString(),
                              sellerId: (chat['seller_id'] ?? '').toString(),
                              productImageUrl: _getDisplayImage(chat),
                            ),
                          ),
                        );
                      },
                    );
                  },
                    ),
            ),
    );
  }
}
