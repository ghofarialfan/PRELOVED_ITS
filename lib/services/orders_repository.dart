import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_item.dart';

class OrdersRepository {
  Future<List<OrderItem>> fetchOrders({required bool isPurchase, required String status}) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return [];
      final key = isPurchase ? 'buyer_id' : 'seller_id';
      final rows = await client
          .from('orders')
          .select()
          .eq(key, user.id)
          .eq('status', status);
      return (rows as List<dynamic>)
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
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

