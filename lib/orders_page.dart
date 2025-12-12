import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _tabIndex = 0;
  String _status = 'Selesai';

  final List<Map<String, String>> _items = List.generate(6, (i) {
    return {
      'order': '#92287157',
      'seller': 'April06',
      'desc': 'Lorem ipsum dolor sit amet consectetur.',
      'img': 'https://picsum.photos/seed/p$i/120/90',
    };
  });

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    const blueSoft = Color(0xFFE9F0FF);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Pesanan'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tabIndex == 0 ? primaryBlue : blueSoft,
                    foregroundColor: _tabIndex == 0 ? Colors.white : primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => setState(() => _tabIndex = 0),
                  child: const Text('Pembelian'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tabIndex == 1 ? primaryBlue : blueSoft,
                    foregroundColor: _tabIndex == 1 ? Colors.white : primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => setState(() => _tabIndex = 1),
                  child: const Text('penjualan'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            items: const [
              DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
              DropdownMenuItem(value: 'Dibatalkan', child: Text('Dibatalkan')),
              DropdownMenuItem(value: 'Dalam Proses', child: Text('Dalam Proses')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBlue, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBlue, width: 2),
              ),
            ),
            icon: const Icon(CupertinoIcons.chevron_down, color: primaryBlue),
          ),
          const SizedBox(height: 12),
          ..._items.map((e) => _OrderTile(data: e)),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Map<String, String> data;
  const _OrderTile({required this.data});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4)),
      ]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              data['img']!,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                width: 72,
                height: 72,
                color: const Color(0xFFE9F0FF),
                child: const Icon(CupertinoIcons.photo, color: primaryBlue),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ${data['order']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(data['desc']!, style: const TextStyle(color: Color(0xFF8E99AF))),
                const SizedBox(height: 4),
                Text(data['seller']!, style: const TextStyle(color: Colors.black)),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryBlue, width: 2),
              foregroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () {},
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}
