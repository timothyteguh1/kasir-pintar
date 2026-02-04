import 'package:flutter/material.dart';
import 'package:kasir_pintar_toti/features/products/product_list_page.dart';
import 'package:kasir_pintar_toti/features/master/category_page.dart';
import 'package:kasir_pintar_toti/features/master/supplier_page.dart';
import 'package:kasir_pintar_toti/features/master/customer_page.dart';

class MasterDataPage extends StatefulWidget {
  final VoidCallback onBack; // Tombol kembali ke Home

  const MasterDataPage({super.key, required this.onBack});

  @override
  State<MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterDataPageState extends State<MasterDataPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Kita punya 4 Halaman
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: widget.onBack, // Balik ke Dashboard
        ),
        title: const Text("Data Master", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          isScrollable: true, // Supaya tab bisa digeser kalau layar sempit
          tabs: const [
            Tab(text: "Gudang Barang"),
            Tab(text: "Kategori"),
            Tab(text: "Pemasok"),
            Tab(text: "Pelanggan"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Gudang (Kita pakai halaman yang lama, tapi tombol back-nya kita matikan di sini karena sudah ada di atas)
          ProductListPage(onBack: widget.onBack), 
          
          // Tab 2: Kategori
          const CategoryPage(),
          
          // Tab 3: Pemasok
          const SupplierPage(),
          
          // Tab 4: Pelanggan
          const CustomerPage(),
        ],
      ),
    );
  }
}