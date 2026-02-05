import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pintar_toti/features/pos/invoice_page.dart';

class SalesTransactionPage extends StatefulWidget {
  const SalesTransactionPage({super.key});

  @override
  State<SalesTransactionPage> createState() => _SalesTransactionPageState();
}

class _SalesTransactionPageState extends State<SalesTransactionPage> {
  // Future untuk mengambil data (Sekali ambil, aman dari crash)
  late Future<QuerySnapshot> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      // Ambil 100 transaksi terakhir agar ringan
      _transactionsFuture = FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(100)
          .get();
    });
  }

  // Fungsi Format Rupiah
  String formatRupiah(num number) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(number);
  }

  // Fungsi Format Tanggal Header (Hari Ini, Kemarin, dll)
  String getGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return "Hari Ini";
    if (checkDate == yesterday) return "Kemarin";
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Riwayat Transaksi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _refreshData,
          )
        ],
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Belum ada data transaksi"));
          }

          final docs = snapshot.data!.docs;

          // --- LOGIKA GROUPING BERDASARKAN TANGGAL ---
          Map<String, List<DocumentSnapshot>> groupedData = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            // Cek keamanan jika date null
            if (data['date'] == null) continue;
            
            final date = (data['date'] as Timestamp).toDate();
            String groupKey = getGroupDate(date);

            if (groupedData[groupKey] == null) {
              groupedData[groupKey] = [];
            }
            groupedData[groupKey]!.add(doc);
          }
          // -------------------------------------------

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedData.keys.length,
            itemBuilder: (context, index) {
              String dateKey = groupedData.keys.elementAt(index);
              List<DocumentSnapshot> transactions = groupedData[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Tanggal
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      dateKey,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  // List Transaksi per Tanggal
                  ...transactions.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = (data['date'] as Timestamp).toDate();
                    final bool isPaid = data['is_paid'] ?? true;

                    return _buildTransactionCard(context, data, date, isPaid);
                  }),
                  
                  const SizedBox(height: 8),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, Map<String, dynamic> data, DateTime date, bool isPaid) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigasi ke Invoice Detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InvoicePage(
                transactionData: data,
                onBackToHome: () => Navigator.pop(context),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon Kiri
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isPaid ? Colors.blue.shade50 : Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_outlined, 
                  color: isPaid ? Colors.blue : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Info Tengah (Expanded mencegah overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DateFormat('HH:mm').format(date),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['invoice_no'] ?? "-",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis, // ANTI OVERFLOW
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['customer_name'] ?? "Umum",
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Info Kanan (Harga & Status)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatRupiah(data['grand_total'] ?? 0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPaid ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isPaid ? "Lunas" : "Hutang",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}