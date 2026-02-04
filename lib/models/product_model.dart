import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String barcode;
  final String category;
  final int price;      // Harga Jual
  final int costPrice;  // Harga Modal
  final int stock;
  final int minStock;   // BARU: Batas Stok Minimum (untuk Alert)
  final String unit;    // BARU: Satuan (Pcs, Kg, Dus, dll)
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> searchKeywords; 

  ProductModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.category,
    required this.price,
    required this.costPrice,
    required this.stock,
    required this.minStock, // Wajib diisi
    required this.unit,     // Wajib diisi
    this.imageUrl,
    required this.createdAt,
    required this.searchKeywords,
  });

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
      // Default ke 5 jika data lama belum punya min_stock
      minStock: data['min_stock'] ?? 5, 
      // Default ke 'Pcs' jika data lama belum punya unit
      unit: data['unit'] ?? 'Pcs',
      imageUrl: data['image_url'],
      createdAt: (data['created_at'] as Timestamp).toDate(),
      searchKeywords: List<String>.from(data['search_keywords'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'barcode': barcode,
      'category': category,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'min_stock': minStock, // Simpan ke DB
      'unit': unit,          // Simpan ke DB
      'image_url': imageUrl,
      'created_at': Timestamp.fromDate(createdAt),
      'search_keywords': searchKeywords,
    };
  }
}