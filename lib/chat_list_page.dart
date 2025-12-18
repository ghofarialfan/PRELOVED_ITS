import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _loadChats() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final res = await _client
        .from('chats')
        .select(
          'id, last_message, updated_at, '
          'seller:sellers(id, name, username, photo_url), '
          'product:products(id, name)',
        )
        .eq('buyer_id', user.id)
        .order('updated_at', ascending: false);

    return (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  String _publicUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    var p = path.trim().replaceFirst(RegExp(r'^/+'), '');
    if (!p.contains('/')) p = 'products/$p';
    return _client.storage.from('products').getPublicUrl(p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pesan"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadChats(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snap.data!;
          if (chats.isEmpty) {
            return const Center(child: Text('Belum ada chat'));
          }

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = chats[i];
              final seller = (c['seller'] as Map?) ?? {};
              final sellerName =
                  (seller['name'] ?? seller['username'] ?? 'Penjual')
                      .toString();
              final sellerPhoto = _publicUrl(
                (seller['photo_url'] ?? '').toString(),
              );

              final product = (c['product'] as Map?) ?? {};
              final productName = (product['name'] ?? '').toString();

              final lastMsg = (c['last_message'] ?? '').toString();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  backgroundImage: sellerPhoto.isNotEmpty
                      ? NetworkImage(sellerPhoto)
                      : null,
                  child: sellerPhoto.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                title: Text(
                  sellerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lastMsg.isNotEmpty
                      ? lastMsg
                      : (productName.isNotEmpty ? productName : 'Mulai chat'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        chatId: c['id'].toString(),
                        sellerId: seller['id'].toString(),
                        sellerName: sellerName,
                        sellerAvatarUrl: sellerPhoto,
                        productId: product['id']?.toString(),
                        productName: productName.isNotEmpty
                            ? productName
                            : null,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
