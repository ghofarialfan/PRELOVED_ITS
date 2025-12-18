import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../chat_page.dart';

class NegoPage extends StatefulWidget {
  final String productId;
  final String productName;
  final String sellerId;
  final String sellerName;
  final String sellerAvatarUrl;

  const NegoPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatarUrl,
  });

  @override
  State<NegoPage> createState() => _NegoPageState();
}

class _NegoPageState extends State<NegoPage> {
  final _client = Supabase.instance.client;
  final hargaController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    hargaController.dispose();
    super.dispose();
  }

  Future<String> _createOrGetChatId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User belum login');

    // cari chat existing untuk product ini
    final existing = await _client
        .from('chats')
        .select('id')
        .eq('buyer_id', user.id)
        .eq('seller_id', widget.sellerId)
        .eq('product_id', widget.productId)
        .maybeSingle();

    if (existing != null) return existing['id'].toString();

    final inserted = await _client
        .from('chats')
        .insert({
          'buyer_id': user.id,
          'seller_id': widget.sellerId,
          'product_id': widget.productId,
          'last_message': 'Mulai nego',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return inserted['id'].toString();
  }

  Future<void> _submitOffer() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan login dulu')));
      return;
    }

    final offer = int.tryParse(
      hargaController.text.replaceAll('.', '').replaceAll(',', '').trim(),
    );

    if (offer == null || offer <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan harga yang valid')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final chatId = await _createOrGetChatId();

      // insert message offer
      await _client.from('chat_messages').insert({
        'chat_id': chatId,
        'sender_id': user.id,
        'message': 'Menawar Rp $offer',
        'message_type': 'offer',
      });

      // update chat last_message
      await _client
          .from('chats')
          .update({
            'last_message': 'Menawar Rp $offer',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', chatId);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            chatId: chatId,
            sellerId: widget.sellerId,
            sellerName: widget.sellerName,
            sellerAvatarUrl: widget.sellerAvatarUrl,
            productId: widget.productId,
            productName: widget.productName,
            offerPrice: offer,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal nego: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nego'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.productName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hargaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Masukkan harga tawaran',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitOffer,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kirim Nego'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
