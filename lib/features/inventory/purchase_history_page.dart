import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pintar_toti/features/inventory/stock_purchase_page.dart';

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({super.key});

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  String formatRupiah(num number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  String formatDate(Timestamp timestamp) {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(timestamp.toDate());
  }

  // --- LOGIKA HAPUS & KOREKSI STOK ---
  Future<void> _deletePurchase(String docId, List<dynamic> items) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Riwayat?"),
        content: const Text(
          "Tindakan ini akan MENGURANGI stok produk sesuai jumlah yang dibeli dalam riwayat ini.\n\nYakin ingin menghapus?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus & Koreksi Stok"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var item in items) {
        String productId = item['id'];
        int qtyPurchased = item['buy_qty']; 

        DocumentReference productRef = FirebaseFirestore.instance.collection('products').doc(productId);

        batch.update(productRef, {
          'stock': FieldValue.increment(-qtyPurchased), 
        });
      }

      DocumentReference purchaseRef = FirebaseFirestore.instance.collection('purchases').doc(docId);
      batch.delete(purchaseRef);

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Riwayat dihapus, stok telah dikoreksi."), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
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
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StockPurchasePage()),
          );
        },
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Stok Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      body: StreamBuilder<QuerySnapshot>(
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
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final date = data['date'] as Timestamp;
              final supplier = data['supplier'] ?? 'Umum';
              final totalItems = data['total_items'] ?? 0;
              final grandTotal = data['grand_total'] ?? 0;
              final List<dynamic> items = data['items'] ?? [];

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
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping, color: Colors.purple, size: 24),
                  ),
                  
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
                  
                  // --- PERBAIKAN DI SINI (TRAILING) ---
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min, // [FIX 1] Agar Column memadat sesuai isi
                    children: [
                      Text(
                        formatRupiah(grandTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue),
                      ),
                      const SizedBox(height: 2), // [FIX 2] Jarak diperkecil (tadinya 4)
                      InkWell(
                        onTap: () => _deletePurchase(doc.id, items),
                        child: Container(
                          // [FIX 3] Padding vertikal diperkecil (tadinya 4)
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline, size: 14, color: Colors.red.shade700),
                              const SizedBox(width: 4),
                              Text(
                                "Batal", 
                                style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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