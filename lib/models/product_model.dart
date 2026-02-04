import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final int price; // Harga Jual
  final int costPrice; // Harga Modal (Penting buat laporan laba)
  final int stock;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> searchKeywords; // Trik untuk pencarian

  ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.price,
    required this.costPrice,
    required this.stock,
    this.imageUrl,
    required this.createdAt,
    required this.searchKeywords,
  });

  // 1. Ubah DATA dari Firebase (Map) menjadi Class Dart
  factory ProductModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      barcode: data['barcode'] ?? '',
      category: data['category'] ?? 'Umum',
      price: data['price'] ?? 0,
      costPrice: data['cost_price'] ?? 0,
      stock: data['stock'] ?? 0,
      imageUrl: data['image_url'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      searchKeywords: List<String>.from(data['search_keywords'] ?? []),
    );
  }

  // 2. Ubah Class Dart menjadi JSON (Map) untuk dikirim ke Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'barcode': barcode,
      'category': category,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'image_url': imageUrl,
      'created_at': Timestamp.fromDate(createdAt),
      'search_keywords': searchKeywords,
    };
  }
}