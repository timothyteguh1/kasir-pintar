import 'package:kasir_pintar_toti/models/product_model.dart';

class CartItem {
  final ProductModel product;
  int qty;

  CartItem({required this.product, this.qty = 1});

  // Hitung Subtotal (Harga x Jumlah)
  int get subtotal => product.price * qty;
  
  // Hitung Total Modal (Untuk laporan Laba nanti)
  int get totalCost => product.costPrice * qty;
}