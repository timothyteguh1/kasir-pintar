import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pintar_toti/features/products/add_product_page.dart';
import 'package:kasir_pintar_toti/models/product_model.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class ProductListPage extends StatefulWidget {
  final VoidCallback onBack; 
  
  const ProductListPage({super.key, required this.onBack});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  late Future<QuerySnapshot> _productsFuture;

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = FirebaseFirestore.instance
          .collection('products')
          .orderBy('created_at', descending: true)
          .get();
    });
  }

  String formatRupiah(int number) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(number);
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'makanan': return Colors.orange.shade100;
      case 'minuman': return Colors.blue.shade100;
      case 'rokok': return Colors.grey.shade300;
      case 'snack': return Colors.yellow.shade100;
      default: return Colors.green.shade50;
    }
  }

  Color _getCategoryTextColor(String category) {
    switch (category.toLowerCase()) {
      case 'makanan': return Colors.orange.shade900;
      case 'minuman': return Colors.blue.shade900;
      case 'rokok': return Colors.grey.shade900;
      case 'snack': return Colors.brown.shade900;
      default: return Colors.green.shade900;
    }
  }

  void deleteProduct(String docId, String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Barang?"),
        content: Text("Yakin ingin menghapus '$productName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('products').doc(docId).delete();
                if (mounted) {
                  showTopSnackBar(Overlay.of(context), CustomSnackBar.success(message: "'$productName' dihapus"));
                  _refreshProducts(); 
                }
              } catch (e) {
                if (mounted) showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: "Gagal: $e"));
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.blue),
              onPressed: widget.onBack, 
              tooltip: "Kembali ke Menu",
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Gudang Barang", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18)),
                Text("Kelola stok & harga", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProductPage()),
          );
          _refreshProducts();
        },
        backgroundColor: const Color(0xFF1E88E5), 
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Tambah Barang", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Cari nama, barcode, atau kategori...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => _searchText = ""); })
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => _searchText = value.toLowerCase()), 
            ),
          ),

          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: _productsFuture, 
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text("Gudang Kosong", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final allProducts = snapshot.data!.docs.map((doc) => ProductModel.fromSnapshot(doc)).where((product) {
                  return product.name.toLowerCase().contains(_searchText) || 
                         product.barcode.toLowerCase().contains(_searchText) ||
                         product.category.toLowerCase().contains(_searchText);
                }).toList();

                if (allProducts.isEmpty) return const Center(child: Text("Barang tidak ditemukan"));

                return RefreshIndicator(
                  onRefresh: () async { _refreshProducts(); },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: allProducts.length,
                    itemBuilder: (context, index) {
                      final product = allProducts[index];
                      final int profit = product.price - product.costPrice;
                      // LOGIKA BARU: Peringatan berdasarkan settingan per barang
                      final bool isLowStock = product.stock <= product.minStock;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ICON DINAMIS
                                  Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      color: isLowStock ? Colors.red.shade50 : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2, 
                                      color: isLowStock ? Colors.red : Colors.blue,
                                      size: 30
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                product.name, 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getCategoryColor(product.category),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                product.category,
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getCategoryTextColor(product.category)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(product.barcode.isEmpty ? "-" : product.barcode, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("Harga Jual", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                Text(formatRupiah(product.price), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                const Text("Stok", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                // TAMPILKAN SATUAN (UNIT)
                                                Text(
                                                  "${product.stock} ${product.unit}", 
                                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLowStock ? Colors.red : Colors.black)
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.trending_up, size: 16, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text("Laba: ${formatRupiah(profit)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                  
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => AddProductPage(productToEdit: product),
                                            ),
                                          );
                                          _refreshProducts(); 
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, size: 16, color: Colors.orange),
                                              SizedBox(width: 4),
                                              Text("Edit", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      InkWell(
                                        onTap: () => deleteProduct(product.id, product.name),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                              SizedBox(width: 4),
                                              Text("Hapus", style: TextStyle(color: Colors.red, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}