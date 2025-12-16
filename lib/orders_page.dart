import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'models/order_item.dart';
import 'services/orders_repository.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _tabIndex = 0;
  String _status = 'Selesai';
  final _repo = OrdersRepository();
  List<OrderItem> _items = const [];
  bool _loading = true;

  Future<void> _openReviewDialog(OrderItem item) async {
    const primaryBlue = Color(0xFF2563FF);
    const blueSoft = Color(0xFFE9F0FF);
    int rating = 0;
    final commentCtrl = TextEditingController();
    bool submitting = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            item.imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(width: 48, height: 48, color: blueSoft, child: const Icon(CupertinoIcons.photo, color: primaryBlue)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Order ${item.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8E99AF))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(5, (i) {
                        final filled = i < rating;
                        return IconButton(
                          onPressed: () => setS(() => rating = i + 1),
                          icon: Icon(filled ? Icons.star : Icons.star_border, color: primaryBlue),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tambahkan Komentar',
                        filled: true,
                        fillColor: blueSoft,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryBlue, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                final nav = Navigator.of(ctx);
                                final messenger = ScaffoldMessenger.of(context);
                                if (rating == 0) {
                                  messenger.showSnackBar(const SnackBar(content: Text('Pilih rating')));
                                  return;
                                }
                                setS(() => submitting = true);
                                try {
                                  await _repo.submitReview(orderId: item.id, rating: rating, comment: commentCtrl.text);
                                  if (!mounted) return;
                                  nav.pop();
                                  messenger.showSnackBar(const SnackBar(content: Text('Review terkirim')));
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(SnackBar(content: Text('Gagal kirim review: $e')));
                                  setS(() => submitting = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: submitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Kirimkan'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _repo.fetchOrders(isPurchase: _tabIndex == 0, status: _status);
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

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
                  onPressed: () async {
                    setState(() => _tabIndex = 0);
                    await _load();
                  },
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
                  onPressed: () async {
                    setState(() => _tabIndex = 1);
                    await _load();
                  },
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
            onChanged: (v) async {
              setState(() => _status = v ?? _status);
              await _load();
            },
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
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                children: const [
                  Icon(CupertinoIcons.cube_box, color: primaryBlue, size: 32),
                  SizedBox(height: 8),
                  Text('Belum ada pesanan', style: TextStyle(color: Color(0xFF8E99AF))),
                ],
              ),
            )
          else
            Column(children: _items.map((e) => _OrderTile(data: e, onReview: _status == 'Selesai' ? () => _openReviewDialog(e) : null)).toList()),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final OrderItem data;
  final VoidCallback? onReview;
  const _OrderTile({required this.data, this.onReview});

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
              data.imageUrl,
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
                Text('Order ${data.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(data.description, style: const TextStyle(color: Color(0xFF8E99AF))),
                const SizedBox(height: 4),
                Text(data.sellerName, style: const TextStyle(color: Colors.black)),
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
            onPressed: onReview,
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}
