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
  bool _saving = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addrCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _postalCtrl = TextEditingController();

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
          _addressLine = [
            line,
            city,
            postal,
          ].where((s) => s.isNotEmpty).join(', ');
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
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Pembayaran',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
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
                          Text(
                            _addressName!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          _addressLine ?? 'Belum ada alamat',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    onEdit: () {
                      _openEditAddress();
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
                          Text(
                            _contactPhone!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          _contactEmail ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    onEdit: () {
                      _openEditAddress();
                    },
                  ),
                  const SizedBox(height: 24),

                  // Barang
                  Row(
                    children: [
                      const Text(
                        'Barang',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.items.length}',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...widget.items.map((item) {
                    final price =
                        (item['discount_price'] ?? item['price'] ?? 0) as num;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: item['image_url'] != null
                                    ? NetworkImage(item['image_url'])
                                    : null,
                                backgroundColor: Colors.grey[200],
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${item['quantity']}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                          Text(
                            _formatCurrency(price),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Shipping Options
                  const Text(
                    'Shipping Options',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatCurrency(_grandTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F1F1F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Bayar'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: '',
          ),
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
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/orders',
        (route) => route.isFirst,
        arguments: 'Belum Dibayar',
      );
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _processPayment() async {
    if (widget.orderId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order ID missing')));
      return;
    }

    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;

      // Update order with final details
      await client
          .from('orders')
          .update({
            'status': 'dikemas',
            'shipping_fee': _shippingCost,
            'total_price': _grandTotal,
            'address_name': _addressName,
            'address_line': _addressLine,
            'address_phone': _contactPhone,
            'address_email': _contactEmail,
          })
          .eq('id', widget.orderId!);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/orders',
        (route) => route.isFirst,
        arguments: 'Dalam Proses',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memproses pembayaran: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Widget _buildSectionCard({
    required String title,
    required Widget content,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
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
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
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

  Widget _buildShippingOption({
    required String title,
    required String subtitle,
    required String price,
    required String value,
  }) {
    final isSelected = _shippingOption == value;
    return InkWell(
      onTap: () => setState(() => _shippingOption = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
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
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.blue[700]),
              ),
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
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
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

  Future<void> _openEditAddress() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        final row = await client
            .from('user_addresses')
            .select('receiver_name, phone, address_line, city, postal_code')
            .eq('user_id', user.id)
            .eq('is_default', true)
            .limit(1)
            .maybeSingle();
        if (row != null) {
          _nameCtrl.text = (row['receiver_name'] ?? '').toString();
          _phoneCtrl.text = (row['phone'] ?? '').toString();
          _addrCtrl.text = (row['address_line'] ?? '').toString();
          _cityCtrl.text = (row['city'] ?? '').toString();
          _postalCtrl.text = (row['postal_code'] ?? '').toString();
        } else {
          final prof = await client
              .from('users')
              .select('full_name, phone')
              .eq('id', user.id)
              .limit(1);
          final list =
              (prof as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              const [];
          if (list.isNotEmpty) {
            _nameCtrl.text = (list.first['full_name'] ?? '').toString();
            _phoneCtrl.text = (list.first['phone'] ?? '').toString();
          } else {
            _nameCtrl.text = (user.email ?? '').split('@').first;
          }
          _addrCtrl.text = _addressLine ?? '';
        }
      }
    } catch (_) {
      _addrCtrl.text = _addressLine ?? '';
    }
    _saving = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              title: const Text('Ubah Alamat Pengirimanmu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Nama penerima',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Nomor telepon',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addrCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Alamat lengkap',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cityCtrl,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Kota',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _postalCtrl,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Kode pos',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setS(() => _saving = true);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final client = Supabase.instance.client;
                            final user = client.auth.currentUser;
                            if (user == null) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Silakan login terlebih dahulu',
                                  ),
                                ),
                              );
                              setS(() => _saving = false);
                              return;
                            }
                            final newAddr = _addrCtrl.text.trim();
                            final name = _nameCtrl.text.trim().isNotEmpty
                                ? _nameCtrl.text.trim()
                                : (user.email ?? '').split('@').first;
                            final phone = _phoneCtrl.text.trim();
                            final city = _cityCtrl.text.trim();
                            final postal = _postalCtrl.text.trim();
                            final existing = await client
                                .from('user_addresses')
                                .select('id')
                                .eq('user_id', user.id)
                                .eq('is_default', true)
                                .limit(1)
                                .maybeSingle();
                            if (existing != null &&
                                (existing['id'] ?? '').toString().isNotEmpty) {
                              await client
                                  .from('user_addresses')
                                  .update({
                                    'receiver_name': name,
                                    'phone': phone,
                                    'address_line': newAddr,
                                    'city': city,
                                    'postal_code': postal,
                                  })
                                  .eq('id', (existing['id'] ?? '').toString())
                                  .eq('user_id', user.id);
                            } else {
                              await client.from('user_addresses').insert({
                                'user_id': user.id,
                                'receiver_name': name,
                                'phone': phone,
                                'address_line': newAddr,
                                'city': city,
                                'postal_code': postal,
                                'is_default': true,
                              });
                            }
                            _addressName = name;
                            _addressLine = [
                              newAddr,
                              city,
                              postal,
                            ].where((e) => e.isNotEmpty).join(', ');
                            _contactPhone = phone.isNotEmpty
                                ? phone
                                : _contactPhone;
                            if (mounted) setState(() {});
                            Navigator.pop(ctx);
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Alamat disimpan')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Gagal menyimpan: $e')),
                            );
                            setS(() => _saving = false);
                          }
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF2563FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCardPaymentSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        const primaryBlue = Color(0xFF2563FF);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Metode Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Sudah'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFF3B30),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFFCC00),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '•••• •••• •••• 1234',
                              style: TextStyle(
                                letterSpacing: 2,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: const [
                                Text(
                                  '2025',
                                  style: TextStyle(color: Colors.black54),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  '12/25',
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'FERDINAND',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          InkWell(
                            onTap: () {},
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
    if (result == true) {
      Map<String, dynamic>? prefetch;
      final first = widget.items.isNotEmpty ? widget.items.first : null;
      final name = first == null
          ? null
          : (first['name'] ?? first['title'])?.toString();
      final image = first == null
          ? null
          : (first['image_url'] ?? '')?.toString();
      final sellerName = first == null
          ? null
          : (first['seller_name'] ?? '')?.toString();
      prefetch = {
        'id': '',
        'order_number': '',
        if (name != null && name.isNotEmpty) 'description': name,
        if (sellerName != null && sellerName.isNotEmpty)
          'seller_name': sellerName,
        if (image != null && image.isNotEmpty) 'image_url': image,
      };
      await _showPaymentSuccess(null, prefetch);
    }
  }

  Future<void> _showQrisSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        const primaryBlue = Color(0xFF2563FF);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Metode Pembayaran',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Icon(
                      Icons.qr_code,
                      size: 180,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Segera Lakukan Pembayaran',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Sudah'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result == true) {
      await _showPaymentSuccess(null, null);
    }
  }

  Future<void> _showPaymentSuccess(
    String? orderId,
    Map<String, dynamic>? prefetch,
  ) async {
    await showGeneralDialog(
      context: context,
      barrierLabel: 'success',
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, a1, a2) {
        return Center(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Pembayaran Berhasil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pembayaran berhasil dilakukan!',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        () async {
                          var id = orderId ?? '';
                          Map<String, dynamic>? pf = prefetch;
                          try {
                            if (id.isEmpty) {
                              id =
                                  await _createPendingOrderAndClearCart() ?? '';
                            }
                            if (pf == null ||
                                ((pf['id'] ?? '') as String).isEmpty) {
                              final first = widget.items.isNotEmpty
                                  ? widget.items.first
                                  : null;
                              final name = first == null
                                  ? null
                                  : (first['name'] ?? first['title'])
                                        ?.toString();
                              final image = first == null
                                  ? null
                                  : (first['image_url'] ?? '')?.toString();
                              final sellerName = first == null
                                  ? null
                                  : (first['seller_name'] ?? '')?.toString();
                              pf = {
                                'id': id,
                                'order_number': id,
                                if (name != null && name.isNotEmpty)
                                  'description': name,
                                if (sellerName != null && sellerName.isNotEmpty)
                                  'seller_name': sellerName,
                                if (image != null && image.isNotEmpty)
                                  'image_url': image,
                              };
                            } else {
                              pf['id'] = id;
                              pf['order_number'] = id;
                            }
                          } catch (_) {
                            if (pf == null ||
                                ((pf['id'] ?? '') as String).isEmpty) {
                              final first = widget.items.isNotEmpty
                                  ? widget.items.first
                                  : null;
                              final name = first == null
                                  ? null
                                  : (first['name'] ?? first['title'])
                                        ?.toString();
                              final image = first == null
                                  ? null
                                  : (first['image_url'] ?? '')?.toString();
                              final sellerName = first == null
                                  ? null
                                  : (first['seller_name'] ?? '')?.toString();
                              pf = {
                                'id': id,
                                'order_number': id,
                                if (name != null && name.isNotEmpty)
                                  'description': name,
                                if (sellerName != null && sellerName.isNotEmpty)
                                  'seller_name': sellerName,
                                if (image != null && image.isNotEmpty)
                                  'image_url': image,
                              };
                            }
                          } finally {
                            Navigator.pop(ctx);
                            Future.microtask(() {
                              if (!mounted) return;
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pushNamed(
                                '/payment_success',
                                arguments: {
                                  'orderId': id,
                                  'items': widget.items,
                                  'total': _grandTotal,
                                  'prefetchOrder': pf,
                                },
                              );
                            });
                          }
                        }();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: const Text('Lacak Pesanan Saya'),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- FUNGSI BARU YANG DITAMBAHKAN UNTUK MEMPERBAIKI ERROR ---
  Future<String?> _createPendingOrderAndClearCart() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return null;

      // 1. Header Order
      final orderRes = await client
          .from('orders')
          .insert({
            'user_id': user.id,
            'status': 'belum dibayar',
            'total_price': _grandTotal,
            'shipping_fee': _shippingCost,
            'address_name': _addressName,
            'address_line': _addressLine,
            'address_phone': _contactPhone,
            'address_email': _contactEmail,
          })
          .select('id')
          .single();

      final newOrderId = orderRes['id'].toString();

      // 2. Order Items
      for (var item in widget.items) {
        await client.from('order_items').insert({
          'order_id': newOrderId,
          'product_id': item['product_id'] ?? item['id'],
          'quantity': item['quantity'] ?? 1,
          'price': item['discount_price'] ?? item['price'] ?? 0,
        });
      }

      // 3. Clear Carts
      await client.from('carts').delete().eq('user_id', user.id);

      return newOrderId;
    } catch (e) {
      debugPrint('Error _createPendingOrderAndClearCart: $e');
      return null;
    }
  }
}
