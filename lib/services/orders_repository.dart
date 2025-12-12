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
}

