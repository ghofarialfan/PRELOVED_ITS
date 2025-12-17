import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_item.dart';

class OrdersRepository {
  Future<List<OrderItem>> fetchOrders({required bool isPurchase, required String status, String? orderId}) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return [];
      final key = isPurchase ? 'buyer_id' : 'seller_id';
      final normalizedStatus = _normalizeStatus(status);
      final qb = client.from('orders').select();
      qb.eq(key, user.id);
      if (orderId != null && orderId.isNotEmpty) {
        qb.eq('id', orderId);
      } else {
        qb.eq('status', normalizedStatus);
      }
      final rows = await qb;
      return (rows as List<dynamic>)
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
  
  String _normalizeStatus(String s) {
    final v = s.trim().toLowerCase();
    if (v == 'selesai' || v == 'completed' || v == 'complete') return 'completed';
    if (v == 'dibatalkan' || v == 'canceled' || v == 'cancelled') return 'canceled';
    if (v == 'dalam proses' || v == 'processing' || v == 'in_progress') return 'processing';
    if (v == 'belum dibayar' || v == 'pending' || v == 'unpaid') return 'pending';
    return s;
  }

  Future<void> submitReview({required String orderId, required int rating, required String comment}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('User belum login');
    }
    await client.from('product_reviews').insert({
      'order_id': orderId,
      'user_id': user.id,
      'rating': rating,
      if (comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }
}
