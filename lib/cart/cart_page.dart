import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:preloved_its/payment/payment_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  int _itemCount = 0;
  String? _addressText;
  bool _loadingAddress = true;
  RealtimeChannel? _channel;
  final TextEditingController _addrCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _postalCtrl = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _items = [];
  bool _loadingItems = true;
  num _total = 0;
  final Set<String> _selectedCartIds = {};
  bool _hoverPesan = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    await Future.wait([
      _loadCartCount(),
      _loadCartItems(),
      _loadDefaultAddress(),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _loadCartCount() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        _itemCount = 0;
        return;
      }
      final rows = await client
          .from('carts')
          .select('quantity')
          .eq('user_id', user.id)
          .gt('quantity', 0);
      final list = (rows as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [];
      int sum = 0;
      for (final m in list) {
        final q = (m['quantity'] ?? 0);
        if (q is num) sum += q.toInt();
      }
      _itemCount = sum;
    } catch (_) {
      _itemCount = 0;
    }
  }

  Future<void> _loadDefaultAddress() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        _addressText = null;
        _loadingAddress = false;
        return;
      }
      final row = await client
          .from('user_addresses')
          .select('receiver_name, phone, address_line, city, postal_code')
          .eq('user_id', user.id)
          .eq('is_default', true)
          .limit(1)
          .maybeSingle();
      if (row != null) {
        final name = (row['receiver_name'] ?? '').toString();
        final line = (row['address_line'] ?? '').toString();
        final city = (row['city'] ?? '').toString();
        final postal = (row['postal_code'] ?? '').toString();
        _addressText = [name, line, city, postal].where((e) => e.isNotEmpty).join(', ');
      }
    } catch (_) {}
    _loadingAddress = false;
  }

  Future<void> _loadCartItems() async {
    _loadingItems = true;
    _items = [];
    _total = 0;
    _selectedCartIds.clear();
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        _loadingItems = false;
        return;
      }
      final carts = await client
          .from('carts')
          .select('id, product_id, quantity, selected')
          .eq('user_id', user.id)
          .gt('quantity', 0);
      final cartList = (carts as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [];
      final productIds = cartList.map((e) => (e['product_id'] ?? '').toString()).where((s) => s.isNotEmpty).toSet().toList();
      List<Map<String, dynamic>> products = [];
      if (productIds.isNotEmpty) {
        final filterVal = '(${productIds.map((e) => '"$e"').join(',')})';
        final resp = await client.from('products').select('*').filter('id', 'in', filterVal);
        products = (resp as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      }
      final byId = {for (final p in products) (p['id'] ?? '').toString(): p};
      final combined = <Map<String, dynamic>>[];
      for (final c in cartList) {
        final pid = (c['product_id'] ?? '').toString();
        final qty = (c['quantity'] ?? 0) as num;
        final p = byId[pid];
        if (p != null) {
          final m = Map<String, dynamic>.from(p);
          m['quantity'] = qty;
          m['cart_id'] = (c['id'] ?? '').toString();
          final sel = (c['selected'] ?? false) == true;
          m['selected'] = sel;
          if (sel && (m['cart_id'] as String).isNotEmpty) {
            _selectedCartIds.add(m['cart_id'] as String);
          }
          combined.add(m);
        }
      }
      if (combined.isNotEmpty) {
        await _attachImages(client, combined);
      }
      _items = combined;
      _recomputeTotal();
      _recomputeCount();
    } catch (_) {}
    _loadingItems = false;
  }

  void _recomputeTotal() {
    num ttl = 0;
    for (final m in _items) {
      final selected = (m['selected'] ?? false) == true && _selectedCartIds.contains((m['cart_id'] ?? '').toString());
      if (!selected) continue;
      final price = (m['discount_price'] ?? m['price'] ?? 0) as num;
      final qty = (m['quantity'] ?? 0) as num;
      ttl += price * qty;
    }
    _total = ttl;
  }

  void _recomputeCount() {
    int sum = 0;
    for (final m in _items) {
      final qty = (m['quantity'] ?? 0) as num;
      sum += qty.toInt();
    }
    _itemCount = sum;
  }

  Future<void> _attachImages(SupabaseClient client, List<Map<String, dynamic>> maps) async {
    try {
      final ids = maps.map((m) => (m['id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
      if (ids.isEmpty) return;
      final coverIdByProduct = <String, String>{};
      for (final m in maps) {
        final pid = (m['id'] ?? '').toString();
        final cid = (m['product_image_id'] ?? '').toString();
        if (pid.isNotEmpty && cid.isNotEmpty) coverIdByProduct[pid] = cid;
      }
      final grouped = <String, String>{};
      if (coverIdByProduct.isNotEmpty) {
        final coverIds = coverIdByProduct.values.toList();
        final coverRows = await client
            .from('product_images')
            .select('id, image_url')
            .filter('id', 'in', '(${coverIds.map((e) => '"$e"').join(',')})');
        final byId = <String, String>{};
        for (final row in (coverRows as List<dynamic>)) {
          final id = (row as Map)['id'].toString();
          final path = (row['image_url'] ?? '').toString();
          if (id.isNotEmpty && path.isNotEmpty) byId[id] = path;
        }
        coverIdByProduct.forEach((pid, cid) {
          final path = byId[cid];
          if (path != null && path.isNotEmpty) grouped[pid] = path;
        });
      }
      final missing = ids.where((pid) => !grouped.containsKey(pid));
      for (final pid in missing) {
        final img = await client
            .from('product_images')
            .select('image_url, order_index')
            .eq('product_id', pid)
            .order('order_index', ascending: true)
            .limit(1)
            .maybeSingle();
        final path = (img?['image_url'] ?? '').toString();
        if (path.isNotEmpty) grouped[pid] = path;
      }
      for (final m in maps) {
        final pid = (m['id'] ?? '').toString();
        var path = grouped[pid] ?? '';
        if (path.isNotEmpty) {
          if (path.startsWith('http')) {
            m['image_url'] = path;
          } else {
            var normalized = path.trim();
            normalized = normalized.replaceFirst(RegExp(r'^/+'), '');
            if (!normalized.contains('/')) {
              normalized = 'products/$normalized';
            }
            m['image_url'] = client.storage.from('products').getPublicUrl(normalized);
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563FF);
    const blueSoft = Color(0xFFE9F0FF);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Keranjang',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: blueSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_itemCount.toString(), style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Alamat Pengiriman', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          if (_loadingAddress)
                            const SizedBox(height: 16, child: LinearProgressIndicator(minHeight: 2))
                          else
                            Text(
                              _addressText?.isNotEmpty == true
                                  ? _addressText!
                                  : 'Belum ada alamat default',
                              style: const TextStyle(color: Color(0xFF8E99AF)),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openEditAddress,
                      icon: const Icon(CupertinoIcons.pencil_circle, color: primaryBlue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _loadingItems
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6)),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(CupertinoIcons.bag_fill, size: 64, color: primaryBlue),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final m = _items[i];
                            final name = (m['name'] ?? m['title'] ?? '').toString();
                            final image = (m['image_url'] ?? '').toString();
                            final price = (m['discount_price'] ?? m['price'] ?? 0) as num;
                            final qty = (m['quantity'] ?? 0) as num;
                            final cartId = (m['cart_id'] ?? '').toString();
                            final selected = (m['selected'] ?? false) == true;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4)),
                              ]),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: selected,
                                    onChanged: (v) => _toggleSelected(cartId, v),
                                    activeColor: primaryBlue,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      image,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(width: 64, height: 64, color: blueSoft, child: const Icon(CupertinoIcons.photo, color: primaryBlue)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text('Rp ${_formatPrice(price)}', style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('x$qty'),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        tooltip: 'Hapus',
                                        onPressed: () => _deleteItem(cartId),
                                        icon: const Icon(CupertinoIcons.trash),
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('Rp ${_formatPrice(_total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoverPesan = true),
                onExit: (_) => setState(() => _hoverPesan = false),
                child: ElevatedButton(
                  onPressed: _selectedCartIds.isEmpty
                      ? null
                      : () {
                          final selectedItems = _items.where((m) {
                            final cartId = (m['cart_id'] ?? '').toString();
                            return _selectedCartIds.contains(cartId);
                          }).toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PaymentPage(items: selectedItems)),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hoverPesan && _selectedCartIds.isNotEmpty ? primaryBlue : Colors.white,
                    foregroundColor: _hoverPesan && _selectedCartIds.isNotEmpty ? Colors.white : Colors.black,
                    disabledBackgroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE0E0E0))),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Pesan'),
                ),
              ),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureRealtime();
  }

  void _ensureRealtime() {
    try {
      if (_channel != null) return;
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      _channel = client.channel('public:carts-user-${user.id}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'carts',
          filter: PostgresChangeFilter(column: 'user_id', value: user.id, type: PostgresChangeFilterType.eq),
          callback: (payload) async {
            await _loadCartCount();
            await _loadCartItems();
            if (mounted) setState(() {});
          },
        )
        ..subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _channel?.unsubscribe();
    } catch (_) {}
    _channel = null;
    _addrCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
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
          final list = (prof as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? const [];
          if (list.isNotEmpty) {
            _nameCtrl.text = (list.first['full_name'] ?? '').toString();
            _phoneCtrl.text = (list.first['phone'] ?? '').toString();
          }
          _addrCtrl.text = _addressText ?? '';
        }
      }
    } catch (_) {
      _addrCtrl.text = _addressText ?? '';
    }
    _saving = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        const primaryBlue = Color(0xFF2563FF);
        return StatefulBuilder(
          builder: (ctx, setS) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(12),
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Text('Ubah Alamat Pengirimanmu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(isDense: true, hintText: 'Nama Penerima', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(isDense: true, hintText: 'Nomor HP', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addrCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(isDense: true, hintText: 'Alamat Lengkap', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(isDense: true, hintText: 'Kota/Desa', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _postalCtrl,
                          decoration: const InputDecoration(isDense: true, hintText: 'Kode Pos', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                              messenger.showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
                              setS(() => _saving = false);
                              return;
                            }
                            final newAddr = _addrCtrl.text.trim();
                            final name = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : (user.email ?? '').split('@').first;
                            final phone = _phoneCtrl.text.trim();
                            final city = _cityCtrl.text.trim();
                            final postal = _postalCtrl.text.trim();
                            final existing = await client
                                .from('user_addresses')
                                .select('id')
                                .eq('user_id', user.id)
                                .eq('is_default', true)
                                .maybeSingle();
                            if (existing != null) {
                              await client
                                  .from('user_addresses')
                                  .update({
                                    'receiver_name': name,
                                    'phone': phone,
                                    'address_line': newAddr,
                                    'city': city,
                                    'postal_code': postal,
                                  })
                                  .eq('id', (existing['id'] ?? '').toString());
                            } else {
                              await client.from('user_addresses').insert({
                                'user_id': user.id,
                                'label': 'Default',
                                'receiver_name': name,
                                'phone': phone,
                                'address_line': newAddr,
                                'city': city,
                                'postal_code': postal,
                                'is_default': true,
                              });
                            }
                            _addressText = newAddr;
                            if (mounted) setState(() {});
                            Navigator.pop(ctx);
                            messenger.showSnackBar(const SnackBar(content: Text('Alamat tersimpan')));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan alamat: $e')));
                            setS(() => _saving = false);
                          }
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatPrice(num n) {
    final s = n.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i - 1;
      buf.write(s[idx]);
      if (i % 3 == 2 && idx != 0) buf.write('.');
    }
    return buf.toString().split('').reversed.join();
  }

  Future<void> _toggleSelected(String cartId, bool? desired) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || cartId.isEmpty) return;

    final next = desired ?? true;

    // Optimistic update
    bool found = false;
    for (final m in _items) {
      if ((m['cart_id'] ?? '').toString() == cartId) {
        m['selected'] = next;
        if (next) {
          _selectedCartIds.add(cartId);
        } else {
          _selectedCartIds.remove(cartId);
        }
        found = true;
        break;
      }
    }
    if (found) {
      _recomputeTotal();
      if (mounted) setState(() {});
    }

    try {
      await client
          .from('carts')
          .update({
            'selected': next,
          })
          .eq('id', cartId)
          .eq('user_id', user.id);
    } catch (e) {
      // Revert if failed
      if (found) {
        final prev = !next;
        for (final m in _items) {
          if ((m['cart_id'] ?? '').toString() == cartId) {
            m['selected'] = prev;
            if (prev) {
              _selectedCartIds.add(cartId);
            } else {
              _selectedCartIds.remove(cartId);
            }
            break;
          }
        }
        _recomputeTotal();
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengubah status: $e')));
      }
    }
  }

  Future<void> _deleteItem(String cartId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Hapus item?'),
          content: const Text('Item akan dihapus dari keranjang.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null || cartId.isEmpty) return;
      await client.from('carts').delete().eq('id', cartId).eq('user_id', user.id);
      _selectedCartIds.remove(cartId);
      _items.removeWhere((m) => (m['cart_id'] ?? '').toString() == cartId);
      _recomputeTotal();
      _recomputeCount();
      if (mounted) setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item dihapus')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
    }
  }
}
