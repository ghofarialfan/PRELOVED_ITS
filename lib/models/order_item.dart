class OrderItem {
  final String id;
  final String orderNumber;
  final String description;
  final String sellerName;
  final String imageUrl;

  const OrderItem({
    required this.id,
    required this.orderNumber,
    required this.description,
    required this.sellerName,
    required this.imageUrl,
  });

  factory OrderItem.fromMap(Map<String, dynamic> m) {
    final id = (m['id'] ?? '').toString();
    final orderNumber = (m['order_number'] ?? id).toString();
    final description = (m['description'] ?? '').toString();
    final sellerName = (m['seller_name'] ?? '').toString();
    final imageUrl = (m['image_url'] ?? '').toString();
    return OrderItem(
      id: id,
      orderNumber: orderNumber,
      description: description,
      sellerName: sellerName,
      imageUrl: imageUrl,
    );
  }
}

