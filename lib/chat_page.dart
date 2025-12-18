import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'payment/payment_page.dart';

class ChatPage extends StatefulWidget {
  final String productId;
  final String productName;
  final String? offerPrice; // Make optional
  final String sellerName;
  final String? sellerAvatar;
  final String? chatId; // Add chatId
  final String sellerId; // Add sellerId
  final String? productImageUrl; // Add productImageUrl

  const ChatPage({
    super.key,
    required this.productId,
    required this.productName,
    this.offerPrice,
    required this.sellerName,
    this.sellerAvatar,
    this.chatId,
    required this.sellerId,
    this.productImageUrl,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageController = TextEditingController();

  late String sellerName;
  late String sellerAvatar;

  List<Map<String, dynamic>> _messages = []; // Use Map for DB rows
  bool _loading = true;
  String? _chatId;
  bool _initialOfferSent = false;

  @override
  void initState() {
    super.initState();
    sellerName = widget.sellerName;
    sellerAvatar = widget.sellerAvatar ?? "https://i.imgur.com/BoN9kdC.png";
    _chatId = widget.chatId;
    
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    // Ensure chat exists and we have _chatId
    await _ensureChat();

    if (_chatId != null) {
      // Subscribe or fetch
      _fetchMessages();
      
      // Realtime subscription
      client
        .channel('public:chat_messages:chat_id=eq.$_chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: _chatId!,
          ),
          callback: (payload) {
            _fetchMessages(); // Reload all or append
          },
        )
        .subscribe();
    }
  }

  Future<void> _ensureChat() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || _chatId != null) return;
    try {
      final existing = await client
          .from('chats')
          .select('id')
          .eq('buyer_id', user.id)
          .eq('seller_id', widget.sellerId)
          .eq('product_id', widget.productId)
          .maybeSingle();
      if (existing != null) {
        _chatId = (existing['id'] ?? '').toString();
        return;
      }
      final inserted = await client
          .from('chats')
          .insert({
            'buyer_id': user.id,
            'seller_id': widget.sellerId,
            'product_id': widget.productId,
            'last_message': 'Mulai nego',
          })
          .select('id')
          .single();
      _chatId = (inserted['id'] ?? '').toString();
    } catch (e) {
      debugPrint('ensureChat error: $e');
    }
  }

  Future<void> _fetchMessages() async {
    if (_chatId == null) return;
    final client = Supabase.instance.client;
    
    final rows = await client
        .from('chat_messages')
        .select('*')
        .eq('chat_id', _chatId!)
        .order('created_at', ascending: true);

    if (mounted) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });

      // Auto-send initial offer if chat is empty and offerPrice is provided
      if (_messages.isEmpty && widget.offerPrice != null && !_initialOfferSent) {
        _initialOfferSent = true;
        final text = "Menawar Rp ${widget.offerPrice}";
        // Send asynchronously to avoid blocking UI or state issues
        Future.microtask(() => _sendText(text, type: 'offer'));
      } else {
        _checkForAutoReply();
      }
    }
  }

  void _checkForAutoReply() {
    if (_messages.isEmpty) return;
    final lastMsg = _messages.last;
    final currentUser = Supabase.instance.client.auth.currentUser;

    // If last message is OFFER and sent by ME (Buyer), simulate Seller reply
    if (lastMsg['sender_id'] == currentUser?.id && lastMsg['message_type'] == 'offer') {
      _simulateSellerResponse();
    }
  }

  Future<void> _handleAcceptOffer(String messageContent) async {
    // 1. Send "Terima" message
    await _sendText("Saya setuju dengan tawaran ini.");

    // 2. Parse price from the counter offer message
    // Message format: "Kalau Rp 1.050.000 bagaimana kak? (Rp 1050000)"
    // Extract the raw value inside the parentheses at the end
    final regex = RegExp(r'\(Rp\s*(\d+)\)');
    final match = regex.firstMatch(messageContent);
    int price = 0;
    
    if (match != null) {
      price = int.tryParse(match.group(1) ?? '0') ?? 0;
    } else {
      // Fallback: try to just grab digits but be careful about duplicates
      // If we failed to match the pattern, maybe just take the first sequence of digits that looks like a price?
      // Or simply stripping non-digits caused the concatenation issue.
      // Let's try to find all digit sequences and take the last one (which is likely the raw one)
      final allDigits = RegExp(r'\d+').allMatches(messageContent).map((m) => m.group(0)).toList();
      if (allDigits.isNotEmpty) {
        // The last one is likely the raw value "1050000" in "(Rp 1050000)"
        price = int.tryParse(allDigits.last ?? '0') ?? 0;
      }
    }

    // 3. Navigate to PaymentPage
    if (!mounted) return;
    
    // Construct items list for PaymentPage
    final items = [{
      'product_id': widget.productId,
      'id': widget.productId,
      'name': widget.productName,
      'price': price,
      'quantity': 1,
      'image_url': (widget.productImageUrl != null && widget.productImageUrl!.isNotEmpty) 
          ? widget.productImageUrl 
          : null,
      'seller_name': widget.sellerName,
      'seller_id': widget.sellerId,
    }];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(items: items),
      ),
    );
  }

  Future<void> _handleRejectOffer() async {
    // 1. Send "Tolak" message
    await _sendText("Maaf, belum cocok.");

    // 2. Terminate and go back (to product detail if that was previous)
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _simulateSellerResponse() async {
    // Wait a bit to simulate thinking
    await Future.delayed(const Duration(seconds: 2));
    
    // Double check if a new message arrived in the meantime
    if (!mounted) return;
    final client = Supabase.instance.client;
    
    // Check if the latest message is still the offer (avoid duplicate replies)
    final check = await client
        .from('chat_messages')
        .select('*')
        .eq('chat_id', _chatId!)
        .order('created_at', ascending: true);
        
    if (check.isNotEmpty) {
      final last = check.last;
      if (last['message_type'] != 'offer') return; // Already replied
    }

    try {
      // Calculate +5%
      final lastText = (check.isNotEmpty ? check.last['message'] : '') .toString();
      
      // Extract digits: "Menawar Rp 2.000.000" -> 2000000
      final digits = lastText.replaceAll(RegExp(r'[^0-9]'), '');
      int offerValue = 0;
      if (digits.isNotEmpty) {
        offerValue = int.tryParse(digits) ?? 0;
      }
      
      // Fallback
      if (offerValue == 0 && widget.offerPrice != null) {
         offerValue = int.tryParse(widget.offerPrice!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
      
      // +5%
      final counterValue = (offerValue * 1.05).round();
      
      // Format: 2.100.000
      String formatCurrency(int value) {
         return value.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
      }
      final formatted = formatCurrency(counterValue);

      // Insert Counter Offer (stored as 'counter' and rendered as incoming)
      final user = client.auth.currentUser; 
      await client.from('chat_messages').insert({
        'chat_id': _chatId,
        'sender_id': user?.id, // Use current user ID to pass RLS
        'message': 'Kalau Rp $formatted bagaimana kak? (Rp $counterValue)',
        'message_type': 'counter',
      });
      
      // Update last message
      await client.from('chats').update({
        'last_message': 'Kalau Rp $formatted bagaimana kak?',
      }).eq('id', _chatId!);
      
    } catch (e) {
      debugPrint("Error simulating seller response: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;
    messageController.clear();
    await _sendText(text);
  }

  Future<void> _sendText(String text, {String type = 'text'}) async {
    if (_chatId == null) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    try {
      await client.from('chat_messages').insert({
        'chat_id': _chatId,
        'sender_id': user?.id,
        'message': text,
        'message_type': type,
      });
      
      // Update last message in chats
      await client.from('chats').update({
        'last_message': text,
      }).eq('id', _chatId!);
      
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }


  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(sellerAvatar)),
            const SizedBox(width: 8),
            Text(sellerName),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMessages,
            tooltip: 'Refresh Chat',
          ),
        ],
      ),

      body: Column(
        children: [
          const SizedBox(height: 8),

          /// INFO PRODUK
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.sell),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.productName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (widget.offerPrice != null && widget.offerPrice != "0")
                        Text("Harga nego: Rp ${widget.offerPrice}"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// CHAT LIST
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchMessages,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(), // Ensure scrollable for RefreshIndicator
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) {
                      final msg = _messages[index];
                      final senderId = msg['sender_id'];
                      final type = msg['message_type'] ?? 'text';
                      // Force counter offers to appear as "others" (left side) even if inserted by me (to bypass RLS)
                      final isMe = (type == 'counter') ? false : (currentUser?.id == senderId);
                      final text = msg['message'] ?? '';

                      return Align(
                        alignment: (type == 'counter')
                            ? Alignment.centerLeft
                            : (isMe ? Alignment.centerRight : Alignment.centerLeft),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (type == 'counter')
                                ? Colors.grey.shade300
                                : (isMe ? Colors.black : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                text,
                                style: TextStyle(
                                  color: (type == 'counter')
                                      ? Colors.black
                                      : (isMe ? Colors.white : Colors.black),
                                ),
                              ),
                              if (type == 'counter' && !isMe) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _handleAcceptOffer(text),
                                    child: const Text("Terima", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: _handleRejectOffer,
                                    child: const Text("Tolak", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),

          /// INPUT FIELD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      hintText: "Tulis pesan...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.black),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
