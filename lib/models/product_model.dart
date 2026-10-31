class ProductModel {
  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final String photoUrl;
  final List<String> contents;
  bool isPackage;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    this.contents = const [],
    this.photoUrl = "",
    this.isPackage = false,
  });

  factory ProductModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return ProductModel(
      id: docId,
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      category: json['category'] ?? 'todos',
      description: json['description'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      isPackage: json['isPackage'] ?? false,
    );
  }
}
