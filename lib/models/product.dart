// lib/models/product.dart


class Product {
  final String id;
  final String name;
  final String category;
  final num price;
  final num rating;
  final String? description;
  final List<String> sizes;
  final String? sellerId;
  final int stock;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final num? discountPrice; 
  final String? condition; 
  final int? totalReviews; 

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.rating,
    this.description,
    required this.sizes,
    this.sellerId,
    required this.stock,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.discountPrice, 
    this.condition,     
    this.totalReviews,  
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    List<String> parsedSizes = [];
    if (map['sizes'] is List) {
        parsedSizes = List<String>.from(map['sizes']);
    } else if (map['sizes'] is String) {
        parsedSizes = (map['sizes'] as String)
            .split(',')
            .map((s) => s.trim())
            .toList();
    }

    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      price: map['price'] as num,
      rating: map['average_rating'] as num? ?? map['rating'] as num? ?? 0, 
      description: map['description'] as String?,
      sizes: parsedSizes,
      sellerId: map['seller_id'] as String?,
      stock: map['stock'] as int? ?? 0,
      imageUrl: map['image_url'] as String?, 
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      discountPrice: map['discount_price'] as num?, 
      condition: map['condition'] as String?,       
      totalReviews: map['total_reviews'] as int?,   
    );
  }
}