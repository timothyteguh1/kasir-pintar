import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pintar_toti/features/common/skeleton_loading.dart'; 
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
  // --- VARIABEL PAGINATION ---
  final int _limit = 10;
  bool _hasNextPage = true;
  bool _isFirstLoadRunning = false;
  bool _isLoadMoreRunning = false;
  List<DocumentSnapshot> _products = [];
  DocumentSnapshot? _lastDocument;

  // --- SEARCH & SCROLL ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _firstLoad();
    _scrollController = ScrollController()..addListener(_loadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. LOAD PERTAMA (RESET) ---
  void _firstLoad() async {
    setState(() {
      _isFirstLoadRunning = true;
      _products = [];
      _hasNextPage = true;
      _lastDocument = null;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('products')
          .orderBy('name') 
          .limit(_limit);

      if (_searchQuery.isNotEmpty) {
        query = query
            .where('name', isGreaterThanOrEqualTo: _searchQuery)
            .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
      }

      final res = await query.get();
      
      if (mounted) {
        setState(() {
          _products = res.docs;
          if (res.docs.isNotEmpty) {
            _lastDocument = res.docs.last;
          } else {
            _hasNextPage = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Error load first: $e");
    }

    if (mounted) setState(() => _isFirstLoadRunning = false);
  }

  // --- 2. LOAD MORE (PAGINATION) ---
  void _loadMore() async {
    if (_hasNextPage &&
        !_isFirstLoadRunning &&
        !_isLoadMoreRunning &&
        _scrollController.position.extentAfter < 300) {
      
      setState(() => _isLoadMoreRunning = true);

      try {
        Query query = FirebaseFirestore.instance.collection('products').orderBy('name');

        if (_searchQuery.isNotEmpty) {
          query = query
              .where('name', isGreaterThanOrEqualTo: _searchQuery)
              .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
        }

        query = query.startAfterDocument(_lastDocument!).limit(_limit);

        final res = await query.get();
        final List<DocumentSnapshot> fetchedProducts = res.docs;

        if (fetchedProducts.isNotEmpty) {
          setState(() {
            _products.addAll(fetchedProducts);
            _lastDocument = fetchedProducts.last;
          });
        } else {
          setState(() => _hasNextPage = false);
        }
      } catch (e) {
        debugPrint("Error load more: $e");
      }

      if (mounted) setState(() => _isLoadMoreRunning = false);
    }
  }

  // --- 3. HELPER UI & LOGIKA ---
  
  ImageProvider? _getImageProvider(String? imageString) {
    if (imageString == null || imageString.isEmpty) return null;
    try {
      return MemoryImage(base64Decode(imageString));
    } catch (e) {
      return null;
    }
  }

  String formatRupiah(int number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
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

  void _deleteProduct(String docId, String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Barang?"),
        content: Text("Yakin ingin menghapus '$productName'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance.collection('products').doc(docId).delete();
                if (mounted) {
                  showTopSnackBar(Overlay.of(context), CustomSnackBar.success(message: "'$productName' dihapus"));
                  _firstLoad(); 
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
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()))
              .then((_) => _firstLoad());
        },
        backgroundColor: const Color(0xFF1E88E5),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Tambah Barang", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Cari nama produk...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                          _firstLoad();
                        })
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _firstLoad();
              },
            ),
          ),

          // --- LIST PRODUK ---
          Expanded(
            child: _isFirstLoadRunning 
                ? _buildSkeletonList()
                : _products.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _products.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _products.length) {
                            return _isLoadMoreRunning 
                                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                                : const SizedBox.shrink();
                          }

                          final doc = _products[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          // --- FIX: MENGISI PARAMETER WAJIB (CREATEDAT & SEARCHKEYWORDS) ---
                          final product = ProductModel(
                            id: doc.id,
                            name: data['name'] ?? '',
                            barcode: data['barcode'] ?? '',
                            category: data['category'] ?? 'Umum',
                            // Cek kedua field (price/sell_price) untuk jaga-jaga
                            price: (data['price'] ?? data['sell_price'] ?? 0).toInt(),
                            costPrice: (data['cost_price'] ?? data['buy_price'] ?? 0).toInt(),
                            stock: (data['stock'] ?? 0).toInt(),
                            imageUrl: data['image_url'],
                            minStock: (data['min_stock'] ?? 5).toInt(),
                            unit: data['unit'] ?? 'Pcs',
                            // --- TAMBAHAN PENTING ---
                            createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
                            searchKeywords: List<String>.from(data['search_keywords'] ?? []),
                          );

                          return _buildProductCard(product);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET ITEMS ---

  Widget _buildProductCard(ProductModel product) {
    final imageProvider = _getImageProvider(product.imageUrl);
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
                // GAMBAR
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: isLowStock ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: isLowStock ? Border.all(color: Colors.red.shade200) : null,
                    image: imageProvider != null
                        ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                        : null,
                  ),
                  child: imageProvider == null
                      ? Icon(
                          isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2,
                          color: isLowStock ? Colors.red : Colors.blue,
                          size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                
                // TEXT DETAIL
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
                              Text(
                                "${product.stock} ${product.unit}",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isLowStock ? Colors.red : Colors.black),
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
            // TOMBOL AKSI
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text("Laba: ${formatRupiah(product.price - product.costPrice)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AddProductPage(productToEdit: product)),
                        );
                        _firstLoad();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Row(children: [Icon(Icons.edit, size: 16, color: Colors.orange), SizedBox(width: 4), Text("Edit", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => _deleteProduct(product.id, product.name),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 4), Text("Hapus", style: TextStyle(color: Colors.red, fontSize: 12))]),
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
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SkeletonContainer(width: 60, height: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonContainer(width: 150, height: 16),
                    SizedBox(height: 8),
                    SkeletonContainer(width: 100, height: 12),
                    SizedBox(height: 8),
                    SkeletonContainer(width: 80, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
}