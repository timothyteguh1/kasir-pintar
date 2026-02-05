import 'dart:convert'; // WAJIB ADA: Untuk decode Base64
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pintar_toti/models/cart_model.dart';
import 'package:kasir_pintar_toti/models/product_model.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:kasir_pintar_toti/features/pos/checkout_page.dart';
import 'package:kasir_pintar_toti/features/pos/invoice_page.dart';

class PosPage extends StatefulWidget {
  final VoidCallback onBack;

  const PosPage({super.key, required this.onBack});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  // --- STATE DATA ---
  String _searchQuery = "";
  String _selectedCategory = "Semua";
  List<ProductModel> _allProducts = [];
  List<String> _categories = ["Semua"];

  // --- STATE KERANJANG ---
  List<CartItem> _cart = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Ambil Data Produk & Kategori Sekaligus
  Future<void> _fetchData() async {
    try {
      final productSnap = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('name')
          .get();
      final products = productSnap.docs
          .map((doc) => ProductModel.fromSnapshot(doc))
          .toList();

      final categorySnap = await FirebaseFirestore.instance
          .collection('categories')
          .get();
      final categories = categorySnap.docs
          .map((doc) => doc['name'].toString())
          .toList();
      categories.sort();
      categories.insert(0, "Semua");

      setState(() {
        _allProducts = products;
        _categories = categories;
      });
    } catch (e) {
      debugPrint("Error load POS data: $e");
    }
  }

  // --- LOGIKA KERANJANG ---

  void _addToCart(ProductModel product) {
    // Cek Stok Dulu
    if (product.stock <= 0) {
      showTopSnackBar(
        Overlay.of(context),
        const CustomSnackBar.error(message: "Stok Habis!"),
      );
      return;
    }

    setState(() {
      final index = _cart.indexWhere((item) => item.product.id == product.id);

      if (index != -1) {
        // Sudah ada -> Tambah Qty (Cek stok lagi)
        if (_cart[index].qty < product.stock) {
          _cart[index].qty++;
        } else {
          showTopSnackBar(
            Overlay.of(context),
            const CustomSnackBar.error(message: "Stok tidak cukup!"),
          );
        }
      } else {
        // Belum ada -> Masukkan baru
        _cart.add(CartItem(product: product));
      }
    });
  }

  void _decreaseQty(int index) {
    setState(() {
      if (_cart[index].qty > 1) {
        _cart[index].qty--;
      } else {
        _cart.removeAt(index); // Kalau sisa 1 dikurang, jadi hapus
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  int get _totalPrice => _cart.fold(0, (sum, item) => sum + item.subtotal);

  String formatRupiah(int number) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(number);
  }

  // --- HELPER UNTUK GAMBAR (BASE64) ---
  ImageProvider? _getImageProvider(String? imageString) {
    if (imageString == null || imageString.isEmpty) return null;
    try {
      // Decode Base64 string ke bytes agar bisa ditampilkan
      return MemoryImage(base64Decode(imageString));
    } catch (e) {
      debugPrint("Error decoding base64 image: $e");
      return null;
    }
  }

  // --- UI BUILDING BLOCKS ---

  // 1. Widget Kategori Chips
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() => _selectedCategory = cat);
              },
              selectedColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
              ),
              backgroundColor: Colors.white,
            ),
          );
        },
      ),
    );
  }

  // 2. Widget Grid Produk (UPDATED: Menampilkan Gambar Base64)
  Widget _buildProductGrid() {
    // Filter List
    final filteredProducts = _allProducts.where((p) {
      final matchCategory =
          _selectedCategory == "Semua" || p.category == _selectedCategory;
      final matchSearch =
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.barcode.contains(_searchQuery);
      return matchCategory && matchSearch;
    }).toList();

    if (filteredProducts.isEmpty) {
      return const Center(child: Text("Barang tidak ditemukan"));
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        final bool isOOS = product.stock <= 0;

        // Ambil Provider Gambar dari String Base64 (bukan URL)
        final ImageProvider? imageProvider = _getImageProvider(product.imageUrl);

        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _addToCart(product),
            splashColor: Colors.blue.withOpacity(0.2),
            highlightColor: Colors.blue.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- BAGIAN GAMBAR / IKON (BASE64 SUPPORT) ---
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOOS ? Colors.grey.shade300 : Colors.blue.shade50,
                      // Logika Gambar Base64: Tampilkan jika ada (tak peduli stok)
                      image: (imageProvider != null)
                          ? DecorationImage(
                              image: imageProvider, // Gunakan MemoryImage hasil decode
                              fit: BoxFit.cover,
                              // Efek Grayscale jika Habis
                              colorFilter: isOOS
                                  ? const ColorFilter.mode(
                                      Colors.grey, BlendMode.saturation)
                                  : null,
                            )
                          : null,
                    ),
                    child: Center(
                      child: isOOS
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "HABIS",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          // Ikon hanya muncul jika TIDAK ADA GAMBAR
                          : (imageProvider == null
                              ? Icon(
                                  Icons.inventory_2,
                                  size: 40,
                                  color: Colors.blue.shade300,
                                )
                              : null),
                    ),
                  ),
                ),
                // --- BAGIAN TEKS ---
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(product.price),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Stok: ${product.stock}",
                        style: TextStyle(
                          fontSize: 10,
                          color: isOOS ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. Widget Keranjang (Cart)
  Widget _buildCartSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header Keranjang
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      "Keranjang (${_cart.length})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (_cart.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() => _cart.clear()),
                    child: const Text(
                      "Hapus Semua",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // List Item Keranjang
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text("Belum ada barang"))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    separatorBuilder: (ctx, i) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${formatRupiah(item.product.price)} x ${item.qty}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Kontrol Qty (+ -)
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _decreaseQty(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  "${item.qty}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.green,
                                ),
                                onPressed: () => _addToCart(
                                  item.product,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatRupiah(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Footer Total & Tombol Bayar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatRupiah(_totalPrice),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _cart.isEmpty
                        ? null
                        : () async {
                            // 1. Buka Checkout & Tunggu Hasilnya (Map Data)
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutPage(
                                  cartItems: _cart,
                                  subtotal: _totalPrice,
                                ),
                              ),
                            );

                            // 2. Jika Sukses (Result berisi Data Transaksi)
                            if (result != null) {
                              setState(() {
                                _cart.clear(); // HAPUS KERANJANG SEKARANG!
                              });
                              _fetchData(); // Refresh Stok
                              
                              // 3. Tampilkan Pesan Sukses
                              showTopSnackBar(
                                Overlay.of(context),
                                const CustomSnackBar.success(message: "Transaksi Berhasil!"),
                              );

                              // 4. Buka Halaman Invoice (Struk)
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => InvoicePage(
                                    transactionData: result, // Data dari Checkout tadi
                                    onBackToHome: () {
                                      Navigator.pop(context); // Tutup Invoice -> Kembali ke Kasir Kosong
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "BAYAR SEKARANG",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- RESPONSIVE LAYOUT (LayoutBuilder) ---
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: widget.onBack,
        ),
        title: const Text(
          "Kasir",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: "Cari Barang...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                        const SizedBox(height: 12),
                        _buildCategoryFilter(),
                        const SizedBox(height: 12),
                        Expanded(child: _buildProductGrid()),
                      ],
                    ),
                  ),
                ),
                Expanded(flex: 4, child: _buildCartSection()),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(
                  flex: 6, 
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            hintText: "Cari Barang...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                        const SizedBox(height: 8),
                        _buildCategoryFilter(),
                        const SizedBox(height: 8),
                        Expanded(child: _buildProductGrid()),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 2),
                Expanded(
                  flex: 4, 
                  child: _buildCartSection(),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}