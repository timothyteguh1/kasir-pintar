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
  // Variabel untuk menyimpan data
  List<DocumentSnapshot> _allTransactions = []; // Data mentah (Semua)
  List<DocumentSnapshot> _filteredTransactions = []; // Data hasil search
  bool _isLoading = true;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // 1. AMBIL DATA DARI FIRESTORE
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('date', descending: true)
          .limit(100) // Batasi 100 terakhir agar ringan
          .get();

      setState(() {
        _allTransactions = snapshot.docs;
        _filteredTransactions = snapshot.docs; // Awalnya tampilkan semua
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching transactions: $e");
      setState(() => _isLoading = false);
    }
  }

  // 2. LOGIKA PENCARIAN (INVOICE / NAMA)
  void _runSearch(String query) {
    if (query.isEmpty) {
      // Kalau kosong, kembalikan ke list penuh
      setState(() => _filteredTransactions = _allTransactions);
      return;
    }

    final lowerQuery = query.toLowerCase();

    setState(() {
      _filteredTransactions = _allTransactions.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        final invoice = (data['invoice_no'] ?? '').toString().toLowerCase();
        final customer = (data['customer_name'] ?? '').toString().toLowerCase();

        // Cek apakah invoice ATAU nama mengandung kata kunci
        return invoice.contains(lowerQuery) || customer.contains(lowerQuery);
      }).toList();
    });
  }

  // Fungsi Format
  String formatRupiah(num number) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(number);
  }

  String getGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return "Hari Ini";
    if (checkDate == yesterday) return "Kemarin";
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text("Riwayat Transaksi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () {
              _searchController.clear();
              _fetchData();
            },
          )
        ],
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _runSearch, // Panggil fungsi cari saat ketik
              decoration: InputDecoration(
                hintText: "Cari Invoice atau Pelanggan...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _runSearch(''); // Reset search
                        },
                      )
                    : null,
              ),
            ),
          ),

          // --- LIST TRANSAKSI ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            const Text("Data tidak ditemukan", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : _buildGroupedList(),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menyusun List Grouping
  Widget _buildGroupedList() {
    // 1. Grouping Data
    Map<String, List<DocumentSnapshot>> groupedData = {};
    
    for (var doc in _filteredTransactions) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['date'] == null) continue;
      
      final date = (data['date'] as Timestamp).toDate();
      String groupKey = getGroupDate(date);

      if (groupedData[groupKey] == null) {
        groupedData[groupKey] = [];
      }
      groupedData[groupKey]!.add(doc);
    }

    // 2. Tampilkan List
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedData.keys.length,
      itemBuilder: (context, index) {
        String dateKey = groupedData.keys.elementAt(index);
        List<DocumentSnapshot> transactions = groupedData[dateKey]!;

        return _buildDateSection(dateKey, transactions);
      },
    );
  }

  Widget _buildDateSection(String dateTitle, List<DocumentSnapshot> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
          child: Text(
            dateTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(transactions.length, (index) {
              final doc = transactions[index];
              final data = doc.data() as Map<String, dynamic>;
              final isLastItem = index == transactions.length - 1;

              return Column(
                children: [
                  _buildTransactionItem(data),
                  if (!isLastItem)
                    const Divider(
                      height: 1, 
                      thickness: 1, 
                      indent: 60, 
                      endIndent: 16,
                      color: Color(0xFFEEEEEE),
                    ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> data) {
    final date = (data['date'] as Timestamp).toDate();
    final bool isPaid = data['is_paid'] ?? true;

    return InkWell(
      onTap: () {
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid ? Icons.check_circle_outline : Icons.pending_outlined,
                color: isPaid ? Colors.green[700] : Colors.red[700],
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data['customer_name'] ?? "Umum",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isPaid)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                          child: const Text("HUTANG", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // HIGHLIGHT SEARCH TEXT (Optional logic, but clean UI)
                  Text(
                    "${DateFormat('HH:mm').format(date)} • ${data['invoice_no'] ?? '-'}",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(data['grand_total'] ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E88E5)),
                ),
                if (!isPaid)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      "Sisa: ${formatRupiah(data['remaining_debt'] ?? 0)}",
                      style: TextStyle(fontSize: 10, color: Colors.red[700]),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}