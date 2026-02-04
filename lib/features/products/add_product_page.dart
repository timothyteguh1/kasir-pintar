import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kasir_pintar_toti/models/product_model.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class AddProductPage extends StatefulWidget {
  final ProductModel? productToEdit;

  const AddProductPage({super.key, this.productToEdit});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final barcodeController = TextEditingController();
  
  String selectedCategory = ""; 
  
  final priceController = TextEditingController(); 
  final costPriceController = TextEditingController();
  
  final stockController = TextEditingController();
  final minStockController = TextEditingController(text: "5");

  final List<String> unitOptions = ['Pcs', 'Kg', 'Gram', 'Liter', 'Pack', 'Dus', 'Lusin', 'Meter', 'Box'];
  String selectedUnit = "Pcs";

  bool isLoading = false;
  List<String> _categoryOptions = [];

  @override
  void initState() {
    super.initState();
    _fetchCategoriesFromMaster(); // Ubah sumber datanya

    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      nameController.text = p.name;
      barcodeController.text = p.barcode;
      selectedCategory = p.category;
      priceController.text = p.price.toString();
      costPriceController.text = p.costPrice.toString();
      stockController.text = p.stock.toString();
      minStockController.text = p.minStock.toString();
      selectedUnit = unitOptions.contains(p.unit) ? p.unit : 'Pcs';
    }
  }

  // UPDATE 1: Ambil data dari koleksi 'categories' (Master Data) agar Cepat & Ringan
  Future<void> _fetchCategoriesFromMaster() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('categories').get();
      final List<String> categories = snapshot.docs.map((doc) => doc['name'].toString()).toList();
      
      setState(() {
        _categoryOptions = categories..sort();
      });
    } catch (e) {
      debugPrint("Gagal ambil kategori master: $e");
    }
  }

  // Fungsi Cek & Simpan Kategori Baru ke Master
  Future<void> _syncCategoryToMaster(String newCategory) async {
    // Cek apakah kategori ini sudah ada di list master kita?
    // Kita pakai toLowerCase() biar "Minuman" dan "minuman" dianggap sama
    bool exists = _categoryOptions.any((c) => c.toLowerCase() == newCategory.toLowerCase());

    if (!exists && newCategory.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('categories').add({
          'name': newCategory, // Simpan nama aslinya (format kapital user)
          'created_at': DateTime.now(),
        });
        debugPrint("Auto-Sync: Kategori '$newCategory' ditambahkan ke Master.");
      } catch (e) {
        debugPrint("Gagal auto-sync kategori: $e");
      }
    }
  }

  List<String> generateSearchKeywords(String name, String barcode) {
    List<String> keywords = [];
    String temp = "";
    for (int i = 0; i < name.length; i++) {
      temp = temp + name[i].toLowerCase();
      keywords.add(temp);
    }
    if (barcode.isNotEmpty) {
      keywords.add(barcode.toLowerCase());
    }
    return keywords;
  }

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // 1. Pastikan kategori terisi
      final finalCategory = selectedCategory.isEmpty ? 'Umum' : selectedCategory;

      // UPDATE 2: Jalankan Auto-Sync ke Master Kategori
      await _syncCategoryToMaster(finalCategory);

      // 3. Lanjut Simpan Produk seperti biasa
      final bool isEditing = widget.productToEdit != null;
      final docRef = isEditing 
          ? FirebaseFirestore.instance.collection('products').doc(widget.productToEdit!.id)
          : FirebaseFirestore.instance.collection('products').doc();

      final product = ProductModel(
        id: docRef.id,
        name: nameController.text,
        barcode: barcodeController.text,
        category: finalCategory,
        price: int.parse(priceController.text),
        costPrice: int.parse(costPriceController.text),
        stock: int.parse(stockController.text.isEmpty ? '0' : stockController.text),
        minStock: int.parse(minStockController.text.isEmpty ? '5' : minStockController.text),
        unit: selectedUnit,
        createdAt: isEditing ? widget.productToEdit!.createdAt : DateTime.now(),
        searchKeywords: generateSearchKeywords(nameController.text, barcodeController.text),
      );

      await docRef.set(product.toMap(), SetOptions(merge: true));

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context), 
          CustomSnackBar.success(message: isEditing ? "Barang Berhasil Diupdate!" : "Barang Baru Disimpan!")
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: "Gagal: $e"));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Barang" : "Tambah Barang Baru"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text("Informasi Dasar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Nama Barang",
                hintText: "Contoh: Kopi Susu",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag_outlined),
                filled: true, fillColor: Colors.white,
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Nama barang wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<String>(
                        initialValue: TextEditingValue(text: selectedCategory),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') return const Iterable<String>.empty();
                          return _categoryOptions.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          selectedCategory = selection;
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          textEditingController.addListener(() {
                            selectedCategory = textEditingController.text;
                          });
                          
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: "Kategori",
                              hintText: "Cth: Minuman",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.category_outlined),
                              filled: true, fillColor: Colors.white,
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: constraints.maxWidth,
                                constraints: const BoxConstraints(maxHeight: 200),
                                color: Colors.white,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final String option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: TextFormField(
                    controller: barcodeController,
                    decoration: const InputDecoration(
                      labelText: "Barcode (Opsional)",
                      hintText: "Scan / Ketik",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                      filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text("Harga & Keuntungan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                children: [
                  TextFormField(
                    controller: costPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Harga Modal (Beli)",
                      prefixText: "Rp ",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.monetization_on_outlined, color: Colors.red),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Harga Modal wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Harga Jual",
                      prefixText: "Rp ",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sell_outlined, color: Colors.green),
                    ),
                    validator: (value) => (value == null || value.isEmpty) ? 'Harga Jual wajib diisi' : null,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            const Text("Persediaan (Stok)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Stok Sekarang",
                      hintText: "0",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warehouse_outlined),
                      filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: "Satuan",
                      border: OutlineInputBorder(),
                      filled: true, fillColor: Colors.white,
                    ),
                    items: unitOptions.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedUnit = newValue!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: minStockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Batas Minimum (Alert)",
                hintText: "Cth: 5",
                helperText: "Warna stok akan merah jika di bawah angka ini",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.orange),
                filled: true, fillColor: Colors.white,
              ),
            ),
            
            const SizedBox(height: 40),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEditing ? Colors.green : const Color(0xFF1E88E5), 
                  foregroundColor: Colors.white, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(isEditing ? "UPDATE BARANG" : "SIMPAN BARANG", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}