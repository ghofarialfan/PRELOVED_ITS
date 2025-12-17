import 'package:flutter/material.dart';
import 'chat_list_page.dart'; // import ChatListPage

/// MODEL CHAT
class ChatMessage {
  final String sender; // buyer / seller
  final String type; // text / offer / counter / payment
  final String message;
  final int? price;

  ChatMessage({
    required this.sender,
    required this.type,
    required this.message,
    this.price,
  });
}

class ChatPage extends StatefulWidget {
  final String productId;
  final String productName;
  final String offerPrice;

  const ChatPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.offerPrice,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageController = TextEditingController();

  final String sellerName = "chokies.shop";
  final String sellerAvatar =
      "https://i.imgur.com/BoN9kdC.png";

  final List<ChatMessage> messages = [];
  int? agreedPrice;

  @override
  void initState() {
    super.initState();

    /// BUYER KIRIM NEGO AWAL
    messages.add(
      ChatMessage(
        sender: "buyer",
        type: "offer",
        message: "Saya menawar harga",
        price: int.parse(widget.offerPrice),
      ),
    );

    /// SELLER AUTO RESPON NEGO
    Future.delayed(const Duration(seconds: 1), () {
      sellerCounterOffer();
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  /// BUYER KIRIM CHAT
  void sendMessage() {
    if (messageController.text.trim().isEmpty) return;

    final text = messageController.text;

    setState(() {
      messages.add(
        ChatMessage(
          sender: "buyer",
          type: "text",
          message: text,
        ),
      );
    });

    messageController.clear();

    /// SELLER AUTO BALAS CHAT
    autoReply(text);
  }

  /// AUTO BALAS SELLER
  void autoReply(String buyerText) async {
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      messages.add(
        ChatMessage(
          sender: "seller",
          type: "text",
          message: "Baik kak, kami cek dulu ya 🙏",
        ),
      );
    });
  }

  /// SELLER KIRIM HARGA BALASAN
  void sellerCounterOffer() {
    setState(() {
      messages.add(
        ChatMessage(
          sender: "seller",
          type: "counter",
          message: "Kalau Rp350.000 bagaimana kak?",
          price: 350000,
        ),
      );
    });
  }

  /// BUYER TERIMA HARGA
  void acceptOffer(int price) {
    setState(() {
      agreedPrice = price;

      messages.add(
        ChatMessage(
          sender: "buyer",
          type: "text",
          message: "Baik, saya setuju",
        ),
      );

      messages.add(
        ChatMessage(
          sender: "seller",
          type: "payment",
          message: "Silakan lanjut ke pembayaran",
        ),
      );
    });
  }

  /// BUYER TOLAK HARGA
  void rejectOffer() {
    setState(() {
      messages.add(
        ChatMessage(
          sender: "buyer",
          type: "text",
          message: "Maaf kak, belum cocok",
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(backgroundImage: NetworkImage(sellerAvatar)),
            const SizedBox(width: 8),
            Text(sellerName),
          ],
        ),
        actions: [
          // Tombol ke ChatListPage
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatListPage(),
                ),
              );
            },
          ),
          // Tombol close untuk keluar dari ChatPage
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text("Harga nego: Rp ${widget.offerPrice}"),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// CHAT LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                final msg = messages[index];
                final isMe = msg.sender == "buyer";

                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.black : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.type == "offer" || msg.type == "counter"
                              ? "${msg.message} (Rp ${msg.price})"
                              : msg.message,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),

                        /// TOMBOL TERIMA / TOLAK (KHUSUS COUNTER SELLER)
                        if (msg.type == "counter" && !isMe) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () =>
                                    acceptOffer(msg.price!),
                                child: const Text("Terima"),
                              ),
                              TextButton(
                                onPressed: rejectOffer,
                                child: const Text("Tolak"),
                              ),
                            ],
                          ),
                        ],

                        /// TOMBOL PAYMENT
                        if (msg.type == "payment") ...[
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Menuju halaman pembayaran"),
                                ),
                              );
                            },
                            child: const Text("Bayar Sekarang"),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          /// INPUT CHAT
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: "Tulis pesan...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
