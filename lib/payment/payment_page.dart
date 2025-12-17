import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class PaymentPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String? orderId;
  
  const PaymentPage({super.key, required this.items, this.orderId});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _shippingOption = 'express'; // 'standard' or 'express'
  String _paymentMethod = 'kartu'; // 'kartu' or 'qris'
  
  String? _addressName;
  String? _addressLine;
  String? _contactPhone;
  String? _contactEmail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await initializeDateFormatting('id_ID', null);
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null) {
      _contactEmail = user.email;
      
      try {
        // Fetch address
        final addr = await client
            .from('user_addresses')
            .select()
            .eq('user_id', user.id)
            .eq('is_default', true)
            .maybeSingle();
            
        if (addr != null) {
          _addressName = addr['receiver_name'] as String?;
          final line = addr['address_line'] as String? ?? '';
          final city = addr['city'] as String? ?? '';
          final postal = addr['postal_code'] as String? ?? '';
          _addressLine = [line, city, postal].where((s) => s.isNotEmpty).join(', ');
          _contactPhone = addr['phone'] as String?;
        }
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  double get _itemsTotal {
    double total = 0;
    for (final item in widget.items) {
      final price = (item['discount_price'] ?? item['price'] ?? 0) as num;
      final qty = (item['quantity'] ?? 0) as num;
      total += price * qty;
    }
    return total;
  }

  double get _shippingCost {
    return _shippingOption == 'express' ? 12000 : 0;
  }

  double get _grandTotal => _itemsTotal + _shippingCost;

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(value);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pembayaran', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _handleBackToOrders,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alamat Pengiriman
                  _buildSectionCard(
                    title: 'Alamat Pengiriman',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_addressName != null) ...[
                          Text(_addressName!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                        ],
                        Text(_addressLine ?? 'Belum ada alamat', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    onEdit: () {
                      // Navigate to address edit or show dialog
                    },
                  ),
                  const SizedBox(height: 16),

                  // Informasi Kontak
                  _buildSectionCard(
                    title: 'Informasi Kontak',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_contactPhone != null) ...[
                          Text(_contactPhone!, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                        ],
                        Text(_contactEmail ?? '', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    onEdit: () {
                      // Edit contact info
                    },
                  ),
                  const SizedBox(height: 24),

                  // Barang
                  Row(
                    children: [
                      const Text('Barang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(12)),
                        child: Text('${widget.items.length}', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...widget.items.map((item) {
                    final price = (item['discount_price'] ?? item['price'] ?? 0) as num;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: item['image_url'] != null ? NetworkImage(item['image_url']) : null,
                                backgroundColor: Colors.grey[200],
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Text('${item['quantity']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['name'] ?? 'Produk',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(_formatCurrency(price), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Shipping Options
                  const Text('Shipping Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildShippingOption(
                    title: 'Standar',
                    subtitle: '2-3 Hari',
                    price: 'GRATIS',
                    value: 'standard',
                  ),
                  const SizedBox(height: 8),
                  _buildShippingOption(
                    title: 'Expres',
                    subtitle: '1 Hari',
                    price: _formatCurrency(12000),
                    value: 'express',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dikirim maksimal ${DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now().add(Duration(days: _shippingOption == 'express' ? 1 : 3)))}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 24),

                  // Metode Pembayaran
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Metode Pembayaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildPaymentChip('Kartu', 'kartu'),
                      const SizedBox(width: 12),
                      _buildPaymentChip('QRIS', 'qris'),
                    ],
                  ),
                ],
              ),
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(_formatCurrency(_grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F1F1F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Bayar'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Batalkan'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          if (i == 0) {
            Navigator.pushNamed(context, '/home');
            return;
          }
          if (i == 1) {
            Navigator.pushNamed(context, '/favorites');
            return;
          }
          if (i == 2) {
            Navigator.pushNamed(context, '/orders');
            return;
          }
          if (i == 4) {
            Navigator.pushNamed(context, '/profile');
            return;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.list_bullet), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.bag), label: ''),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person), label: ''),
        ],
        selectedItemColor: Colors.black,
        unselectedItemColor: primaryBlue,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        backgroundColor: Colors.white,
      ),
    );
  }

  Future<void> _handleBackToOrders() async {
    if (widget.orderId != null) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/orders', (route) => route.isFirst, arguments: 'Belum Dibayar');
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _processPayment() async {
    if (widget.orderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order ID missing')));
      return;
    }
    
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      
      // Update order with final details
      await client.from('orders').update({
        'status': 'dikemas', 
        'shipping_fee': _shippingCost,
        'total_price': _grandTotal,
        'address_name': _addressName,
        'address_line': _addressLine,
        'address_phone': _contactPhone,
        'address_email': _contactEmail,
      }).eq('id', widget.orderId!);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/orders', (route) => route.isFirst, arguments: 'Dalam Proses');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memproses pembayaran: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSectionCard({required String title, required Widget content, required VoidCallback onEdit}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              InkWell(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildShippingOption({required String title, required String subtitle, required String price, required String value}) {
    final isSelected = _shippingOption == value;
    return InkWell(
      onTap: () => setState(() => _shippingOption = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.blue : Colors.grey[300],
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
              child: Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.blue[700])),
            ),
            const Spacer(),
            Text(price, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String label, String value) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.blue) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
