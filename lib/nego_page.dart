import 'package:flutter/material.dart';
import 'chat_page.dart';

class NegoPage extends StatefulWidget {
  final String productId;
  final String productName;
  final int productPrice;
  final String productImage;

  const NegoPage({
    super.key,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productImage,
  });

  @override
  State<NegoPage> createState() => _NegoPageState();
}

class _NegoPageState extends State<NegoPage> {
  final TextEditingController hargaController = TextEditingController();

  @override
  void dispose() {
    hargaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Nego",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ), 
                ],
              ),

              const SizedBox(height: 10),

              // Ringkasan Produk
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.productImage,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text("Rp ${widget.productPrice}"),
                      ],
                    ),
                  )
                ],
              ),

              const SizedBox(height: 16),

              // Input Harga
              TextField(
                controller: hargaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Harga kamu",
                  prefixText: "Rp ",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                "Harga ini belum termasuk ongkir",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // Tombol Kirim
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: () {
                    if (hargaController.text.isEmpty) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          productId: widget.productId,
                          productName: widget.productName,
                          offerPrice: hargaController.text,
                        ),
                      ),
                    );
                  },
                  child: const Text("Kirim nego"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
