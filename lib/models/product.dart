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
  final List<ProductImage> images;

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
    this.images = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    List<ProductImage> productImages = [];
    if (json['product_images'] != null) {
      if (json['product_images'] is List) {
        productImages = (json['product_images'] as List)
            .map((img) => ProductImage.fromJson(Map<String, dynamic>.from(img)))
            .toList();
      }
    }

    List<String> sizesList = [];
    if (json['sizes'] != null) {
      if (json['sizes'] is List) {
        sizesList = List<String>.from(json['sizes']);
      } else if (json['sizes'] is String) {
        sizesList = (json['sizes'] as String).split(',').map((s) => s.trim()).toList();
      }
    }

    return Product(
      id: (json['id'] != null) ? json['id'].toString() : '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      price: json['price'] is num ? json['price'] as num : (num.tryParse(json['price']?.toString() ?? '') ?? 0),
      rating: json['rating'] is num ? json['rating'] as num : (num.tryParse(json['rating']?.toString() ?? '') ?? 0),
      description: json['description'],
      sizes: sizesList,
      sellerId: (json['seller_id'] ?? json['sellerId'])?.toString(),
      stock: json['stock'] ?? 0,
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null),
      discountPrice: json['discount_price'] is num ? json['discount_price'] as num : (num.tryParse(json['discount_price']?.toString() ?? '')),
      condition: json['condition'],
      totalReviews: json['total_reviews'] ?? json['totalReviews'],
      images: productImages,
    );
  }

  /// Backwards-compatible alias for existing code using `fromMap`.
  factory Product.fromMap(Map<String, dynamic> map) => Product.fromJson(Map<String, dynamic>.from(map));
}

class ProductImage {
  final String id;
  final String productId;
  final String imageUrl;
  final int displayOrder;

  ProductImage({
    required this.id,
    required this.productId,
    required this.imageUrl,
    required this.displayOrder,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? json['productId'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      displayOrder: json['display_order'] ?? json['displayOrder'] ?? json['order_index'] ?? json['orderIndex'] ?? 0,
    );
  }
}
