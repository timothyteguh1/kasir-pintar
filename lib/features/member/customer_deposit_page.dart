import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomerDepositPage extends StatefulWidget {
  const CustomerDepositPage({super.key});

  @override
  State<CustomerDepositPage> createState() => _CustomerDepositPageState();
}

class _CustomerDepositPageState extends State<CustomerDepositPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Format Rupiah
  String formatRupiah(num number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  // --- FUNGSI TOP UP SALDO ---
  void _showTopUpDialog(BuildContext context, String customerId, String customerName, int currentBalance) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Top Up Deposit"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Pelanggan: $customerName", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text("Saldo saat ini: ${formatRupiah(currentBalance)}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Nominal Top Up",
                prefixText: "Rp ",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              if (amountController.text.isEmpty) return;
              int amount = int.parse(amountController.text.replaceAll('.', '')); // Hapus titik jika ada

              if (amount <= 0) return;

              Navigator.pop(context); // Tutup Dialog
              _processTopUp(customerId, customerName, amount);
            },
            child: const Text("Simpan Deposit"),
          ),
        ],
      ),
    );
  }

  Future<void> _processTopUp(String customerId, String name, int amount) async {
    // Tampilkan Loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();

      // 1. Update Saldo Customer
      final customerRef = FirebaseFirestore.instance.collection('customers').doc(customerId);
      batch.update(customerRef, {
        'deposit_balance': FieldValue.increment(amount), // Tambah saldo
        'updated_at': Timestamp.fromDate(now),
      });

      // 2. Catat Riwayat Deposit (Agar uangnya jelas lari kemana)
      final historyRef = FirebaseFirestore.instance.collection('deposit_history').doc();
      batch.set(historyRef, {
        'customer_id': customerId,
        'customer_name': name,
        'type': 'in', // 'in' = Masuk (Top Up), 'out' = Keluar (Dipakai Belanja)
        'amount': amount,
        'date': Timestamp.fromDate(now),
        'note': 'Top Up Manual',
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Top Up Berhasil!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text("Deposit Pelanggan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Cari Pelanggan...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // --- LIST CUSTOMER ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('customers').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                // Filter Data Lokal (Client Side Search)
                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String name = (data['name'] ?? '').toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("Pelanggan tidak ditemukan", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String name = data['name'] ?? 'Tanpa Nama';
                    String phone = data['phone'] ?? '-';
                    // Ambil saldo, kalau belum ada anggap 0
                    int balance = data['deposit_balance'] ?? 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        // Ikon Dompet
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.teal, size: 24),
                        ),
                        
                        // Nama & No HP
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(phone, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        
                        // Saldo & Tombol Top Up
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatRupiah(balance),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: balance > 0 ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Label kecil "Top Up"
                            InkWell(
                              onTap: () => _showTopUpDialog(context, docs[index].id, name, balance),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  "+ Top Up",
                                  style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                ),
                              ),
                            )
                          ],
                        ),
                        // Klik seluruh baris juga bisa buat Top Up
                        onTap: () => _showTopUpDialog(context, docs[index].id, name, balance),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}