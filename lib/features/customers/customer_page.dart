import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomerPage extends StatefulWidget {
  // 1. Tambahkan parameter onBack
  final VoidCallback? onBack; 

  const CustomerPage({super.key, this.onBack});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  void _showCustomerDialog({String? docId, String? currentName, String? currentPhone}) {
    // ... (Logika Dialog TETAP SAMA seperti sebelumnya) ...
    // Copy paste isi _showCustomerDialog dari kode sebelumnya
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? "Tambah Pelanggan" : "Edit Pelanggan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nama Pelanggan", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "No. HP / WA", border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              if (docId == null) {
                await FirebaseFirestore.instance.collection('customers').add({
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'deposit_balance': 0,
                  'created_at': DateTime.now(),
                });
              } else {
                await FirebaseFirestore.instance.collection('customers').doc(docId).update({
                  'name': nameController.text,
                  'phone': phoneController.text,
                });
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  void _deleteCustomer(String docId) {
     // ... (Logika Hapus TETAP SAMA) ...
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Pelanggan?"),
        content: const Text("Data pelanggan dan saldo depositnya akan hilang permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('customers').doc(docId).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  String formatRupiah(num number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text("Data Pelanggan", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        // 2. MODIFIKASI TOMBOL KEMBALI
        // Jika onBack ada (dipanggil dari Home), pakai onBack.
        // Jika tidak (dipanggil dari tempat lain), pakai Navigator.pop.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerDialog(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Cari nama pelanggan...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('customers').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return (data['name'] ?? '').toLowerCase().contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) return const Center(child: Text("Belum ada data pelanggan"));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    int balance = data['deposit_balance'] ?? 0;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: Text((data['name'] ?? 'U')[0].toUpperCase(), style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(data['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['phone'] ?? '-', style: const TextStyle(color: Colors.grey)),
                            if (balance > 0) Text("Deposit: ${formatRupiah(balance)}", style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.orange, size: 20), onPressed: () => _showCustomerDialog(docId: docs[index].id, currentName: data['name'], currentPhone: data['phone'])),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteCustomer(docs[index].id)),
                          ],
                        ),
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