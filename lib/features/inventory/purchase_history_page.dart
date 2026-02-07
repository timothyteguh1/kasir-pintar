import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pintar_toti/features/inventory/stock_purchase_page.dart'; // Import halaman Form yang tadi

class PurchaseHistoryPage extends StatelessWidget {
  const PurchaseHistoryPage({super.key});

  String formatRupiah(num number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  String formatDate(Timestamp timestamp) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7), // Abu soft background
      appBar: AppBar(
        title: const Text("Riwayat Pembelian", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      
      // --- TOMBOL TAMBAH (+) ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigasi ke Form Pembelian (Page yang tadi)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StockPurchasePage()),
          );
        },
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Stok Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      // --- LIST RIWAYAT ---
      body: StreamBuilder<QuerySnapshot>(
        // Ambil data 'purchases', urutkan dari yang terbaru
        stream: FirebaseFirestore.instance
            .collection('purchases')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("Belum ada riwayat pembelian", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final date = data['date'] as Timestamp;
              final supplier = data['supplier'] ?? 'Umum';
              final totalItems = data['total_items'] ?? 0;
              final grandTotal = data['grand_total'] ?? 0;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  // Ikon Truk
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping, color: Colors.purple, size: 24),
                  ),
                  
                  // Info Supplier & Tanggal
                  title: Text(
                    supplier, 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(formatDate(date), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      const SizedBox(height: 4),
                      Text("$totalItems item dibeli", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                  
                  // Total Harga
                  trailing: Text(
                    formatRupiah(grandTotal),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}