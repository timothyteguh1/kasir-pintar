import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StockPurchasePage extends StatefulWidget {
  const StockPurchasePage({super.key});

  @override
  State<StockPurchasePage> createState() => _StockPurchasePageState();
}

class _StockPurchasePageState extends State<StockPurchasePage> {
  final TextEditingController _supplierController = TextEditingController();
  final FocusNode _supplierFocusNode = FocusNode();
  
  List<String> _supplierList = []; 
  List<Map<String, dynamic>> _purchaseCart = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSuppliers();
  }

  // --- 0. AMBIL DATA SUPPLIER ---
  Future<void> _fetchSuppliers() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('suppliers').get();
      setState(() {
        _supplierList = snapshot.docs.map((doc) => doc['name'] as String).toList();
      });
    } catch (e) {
      debugPrint("Error fetching suppliers: $e");
    }
  }

  // --- 1. CARI BARANG ---
  void _showProductSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Pilih Produk", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('products').orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var products = snapshot.data!.docs;
                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      var data = products[index].data() as Map<String, dynamic>;
                      String id = products[index].id;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Stok saat ini: ${data['stock']}"),
                        trailing: const Icon(Icons.add_circle_outline, color: Colors.blue),
                        onTap: () {
                          Navigator.pop(context);
                          _showInputQtyPrice(id, data);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. INPUT QTY & HARGA ---
  void _showInputQtyPrice(String id, Map<String, dynamic> productData) {
    final qtyController = TextEditingController();
    final priceController = TextEditingController(text: (productData['cost_price'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(productData['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Jumlah Beli", border: OutlineInputBorder(), suffixText: "Pcs"),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Harga Beli (Modal)", border: OutlineInputBorder(), prefixText: "Rp "),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              if (qtyController.text.isEmpty || priceController.text.isEmpty) return;
              int qty = int.parse(qtyController.text);
              int price = int.parse(priceController.text);
              setState(() {
                _purchaseCart.add({
                  'id': id,
                  'name': productData['name'],
                  'current_stock': productData['stock'],
                  'buy_qty': qty,
                  'buy_price': price,
                  'total': qty * price,
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Tambahkan"),
          ),
        ],
      ),
    );
  }

  // --- 3. SIMPAN STOK ---
  Future<void> _savePurchase() async {
    if (_purchaseCart.isEmpty) return;
    setState(() => _isLoading = true);
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    try {
      final purchaseRef = FirebaseFirestore.instance.collection('purchases').doc();
      batch.set(purchaseRef, {
        'date': Timestamp.fromDate(now),
        'supplier': _supplierController.text.isEmpty ? "Umum" : _supplierController.text,
        'total_items': _purchaseCart.length,
        'grand_total': _purchaseCart.fold(0, (sum, item) => sum + (item['total'] as int)),
        'items': _purchaseCart,
      });

      for (var item in _purchaseCart) {
        final productRef = FirebaseFirestore.instance.collection('products').doc(item['id']);
        batch.update(productRef, {
          'stock': FieldValue.increment(item['buy_qty']),
          'cost_price': item['buy_price'],
          'updated_at': Timestamp.fromDate(now),
        });
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stok Berhasil Ditambahkan!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan data"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String formatRupiah(num number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  @override
  Widget build(BuildContext context) {
    int grandTotal = _purchaseCart.fold(0, (sum, item) => sum + (item['total'] as int));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Pembelian Stok", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // --- HEADER: SUPPLIER (AUTOCOMPLETE RAPI) ---
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF9FAFB), // Background header sedikit abu
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Informasi Supplier", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                
                // WIDGET AUTOCOMPLETE
                LayoutBuilder(
                  builder: (context, constraints) {
                    return RawAutocomplete<String>(
                      textEditingController: _supplierController,
                      focusNode: _supplierFocusNode,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') return const Iterable<String>.empty();
                        return _supplierList.where((String option) {
                          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      
                      // --- TAMPILAN DROPDOWN (MIRIP GAMBAR REFERENSI) ---
                      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4.0, // Bayangan agar melayang
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8), // Sudut melengkung
                            child: Container(
                              width: constraints.maxWidth, // Lebar SAMA PERSIS dengan kolom input
                              constraints: const BoxConstraints(maxHeight: 200), // Tinggi maksimal
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final String option = options.elementAt(index);
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                    title: Text(option),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },

                      // --- TAMPILAN KOLOM INPUT ---
                      fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                        return TextField(
                          controller: fieldTextEditingController,
                          focusNode: fieldFocusNode,
                          decoration: InputDecoration(
                            labelText: "Cari Supplier",
                            hintText: "Ketik nama supplier...",
                            prefixIcon: const Icon(Icons.store, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                          ),
                        );
                      },
                    );
                  }
                ),
              ],
            ),
          ),

          // --- LIST ITEMS (CART) ---
          Expanded(
            child: _purchaseCart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart, size: 80, color: Colors.grey[200]),
                        const SizedBox(height: 16),
                        const Text("Keranjang stok masih kosong", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _purchaseCart.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _purchaseCart[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${formatRupiah(item['buy_price'])} x ${item['buy_qty']} pcs"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatRupiah(item['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _purchaseCart.removeAt(index);
                                });
                              },
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // --- FOOTER BUTTON ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Tagihan", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(formatRupiah(grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showProductSelector,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("+ Tambah Item"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _purchaseCart.isEmpty || _isLoading ? null : _savePurchase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isLoading 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("SIMPAN STOK"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}