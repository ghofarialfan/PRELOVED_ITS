import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String sellerId;
  final String sellerName;
  final String sellerAvatarUrl;

  final String? productId;
  final String? productName;
  final int? offerPrice;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatarUrl,
    this.productId,
    this.productName,
    this.offerPrice,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _client = Supabase.instance.client;

  final _textC = TextEditingController();
  final _scrollC = ScrollController();

  bool _loading = true;
  List<Map<String, dynamic>> _messages = [];

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _textC.dispose();
    _scrollC.dispose();
    _unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      setState(() => _loading = true);

      final res = await _client
          .from('chat_messages')
          .select('*')
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true);

      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _jumpToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memuat chat: $e')));
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollC.hasClients) return;
      _scrollC.jumpTo(_scrollC.position.maxScrollExtent);
    });
  }

  void _subscribeRealtime() {
    // ✅ FIX sesuai versi kamu: filter wajib PostgresChangeFilter
    _channel = _client
        .channel('chat:${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            if (!mounted) return;

            setState(() {
              _messages.add(Map<String, dynamic>.from(record));
            });
            _jumpToBottom();
          },
        )
        .subscribe();
  }

  Future<void> _unsubscribe() async {
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      await _client.removeChannel(ch);
    }
  }

  Future<void> _sendText() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Silakan login dulu')));
      return;
    }

    final text = _textC.text.trim();
    if (text.isEmpty) return;

    _textC.clear();

    try {
      await _client.from('chat_messages').insert({
        'chat_id': widget.chatId,
        'sender_id': user.id,
        'message': text,
        'message_type': 'text',
      });

      await _client
          .from('chats')
          .update({
            'last_message': text,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.chatId);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal kirim pesan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[200],
              backgroundImage: widget.sellerAvatarUrl.isNotEmpty
                  ? NetworkImage(widget.sellerAvatarUrl)
                  : null,
              child: widget.sellerAvatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.sellerName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.productName != null && widget.productName!.isNotEmpty)
            _productHeader(),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollC,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final senderId = (m['sender_id'] ?? '').toString();
                      final isMe = myId != null && senderId == myId;
                      final msg = (m['message'] ?? '').toString();

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.black : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            msg,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textC,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sell, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productName ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (widget.offerPrice != null)
                  Text(
                    'Harga nego: Rp ${widget.offerPrice}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
