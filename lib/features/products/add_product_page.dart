import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kasir_pintar_toti/models/product_model.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  // Controller untuk semua inputan
  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  final categoryController = TextEditingController(); // Input Kategori
  final priceController = TextEditingController(); // Harga Jual
  final costPriceController = TextEditingController(); // Harga Modal
  final stockController = TextEditingController();

  bool isLoading = false;

  // Fungsi Pembantu: Membuat Keyword Pencarian (Biar user gampang cari barang)
  // Contoh: "Kopi" -> ["k", "ko", "kop", "kopi"]
  List<String> generateSearchKeywords(String text) {
    List<String> keywords = [];
    String temp = "";
    for (int i = 0; i < text.length; i++) {
      temp = temp + text[i].toLowerCase();
      keywords.add(temp);
    }
    return keywords;
  }

  Future<void> saveProduct() async {
    // 1. Validasi Input (Wajib Diisi)
    if (nameController.text.isEmpty || 
        priceController.text.isEmpty || 
        costPriceController.text.isEmpty) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "Nama, Harga Jual, dan Modal wajib diisi!"));
      return;
    }

    setState(() => isLoading = true);

    try {
      // 2. Siapkan Referensi Dokumen Baru
      final docRef = FirebaseFirestore.instance.collection('products').doc();

      // 3. Buat Objek ProductModel (Sesuai Model Canggih Kamu)
      final product = ProductModel(
        id: docRef.id,
        name: nameController.text,
        barcode: barcodeController.text,
        category: categoryController.text.isEmpty ? 'Umum' : categoryController.text,
        price: int.parse(priceController.text),
        costPrice: int.parse(costPriceController.text), // Harga Modal
        stock: int.parse(stockController.text.isEmpty ? '0' : stockController.text),
        createdAt: DateTime.now(),
        searchKeywords: generateSearchKeywords(nameController.text), // Generate keyword otomatis
      );

      // 4. Kirim ke Firebase
      await docRef.set(product.toMap());

      if (mounted) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: "Barang berhasil disimpan ke Gudang!"));
        Navigator.pop(context); // Kembali ke Home
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: "Gagal: $e"));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Barang Lengkap")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Input Nama Barang
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Nama Barang",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Input Kategori & Barcode
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: "Kategori (Opsional)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                    hintText: "Cth: Makanan",
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: barcodeController,
                  decoration: const InputDecoration(
                    labelText: "Barcode",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Input Harga Jual & Harga Modal (PENTING BUAT LABA)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Harga Jual (Rp)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sell_outlined, color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: costPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Harga Modal (Rp)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monetization_on_outlined, color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Input Stok
          TextField(
            controller: stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Stok Awal",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.warehouse_outlined),
            ),
          ),
          const SizedBox(height: 30),

          // Tombol Simpan
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : saveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("SIMPAN BARANG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}