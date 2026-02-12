import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kasir_pintar_toti/features/common/skeleton_loading.dart'; // Pastikan path ini benar

class SalesTransactionPage extends StatefulWidget {
  // --- PERBAIKAN: Menambahkan parameter onBack ---
  final VoidCallback? onBack; 

  const SalesTransactionPage({super.key, this.onBack});

  @override
  State<SalesTransactionPage> createState() => _SalesTransactionPageState();
}

class _SalesTransactionPageState extends State<SalesTransactionPage> {
  // --- VARIABLES ---
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Statistik Ringkas
  double _totalOmzet = 0;
  int _totalTransaksi = 0;

  // Default: 7 Hari Terakhir
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)), 
    end: DateTime.now()
  );

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  // --- 1. CORE LOGIC: FETCH DATA ---
  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _totalOmzet = 0;
      _totalTransaksi = 0;
    });

    DateTime start = DateTime(_selectedRange.start.year, _selectedRange.start.month, _selectedRange.start.day);
    DateTime end = DateTime(_selectedRange.end.year, _selectedRange.end.month, _selectedRange.end.day, 23, 59, 59);

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      List<Map<String, dynamic>> tempData = [];
      double tempOmzet = 0;

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        double amount = (data['grand_total'] ?? 0).toDouble();
        tempOmzet += amount;

        tempData.add(data);
      }

      // Sort Descending (Terbaru diatas)
      tempData.sort((a, b) {
        Timestamp tA = a['date'] as Timestamp;
        Timestamp tB = b['date'] as Timestamp;
        return tB.compareTo(tA);
      });

      if (mounted) {
        setState(() {
          _transactions = tempData;
          _totalOmzet = tempOmzet;
          _totalTransaksi = tempData.length;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Gagal memuat: $e";
        });
      }
    }
  }

  String formatRupiah(num number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  String _getGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final check = DateTime(date.year, date.month, date.day);

    if (check == today) return "HARI INI";
    if (check == yesterday) return "KEMARIN";
    return DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(date).toUpperCase();
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedRange = picked);
      _fetchTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text("Riwayat Transaksi", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        // --- PERBAIKAN: Tombol Back dipasang di sini ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.blue),
          // Jika onBack ada (dari Home), pakai itu. Kalau tidak, pakai pop biasa.
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.blue),
            onPressed: _pickDateRange,
          )
        ],
      ),
      body: Column(
        children: [
          // HEADER RINGKASAN
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  "Total Omzet (${DateFormat('dd MMM').format(_selectedRange.start)} - ${DateFormat('dd MMM').format(_selectedRange.end)})",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                _isLoading
                    ? Container(height: 30, width: 150, color: Colors.grey[200])
                    : Text(
                        formatRupiah(_totalOmzet),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    "$_totalTransaksi Transaksi Berhasil",
                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // LIST TRANSAKSI
          Expanded(
            child: _isLoading 
                ? _buildSkeletonList()
                : _errorMessage != null 
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _transactions.isEmpty
                        ? _buildEmptyState()
                        : _buildGroupedList(),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildGroupedList() {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in _transactions) {
      DateTime date = (item['date'] as Timestamp).toDate();
      String key = _getGroupDate(date);
      if (grouped[key] == null) grouped[key] = [];
      grouped[key]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        String dateKey = grouped.keys.elementAt(index);
        List<Map<String, dynamic>> items = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text(
                dateKey,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0),
              ),
            ),
            ...items.map((item) => _buildTransactionCard(item)),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    DateTime date = (item['date'] as Timestamp).toDate();
    String paymentMethod = item['payment_method'] ?? 'Tunai';
    String customerName = item['customer_name'] ?? 'Pelanggan Umum';
    
    IconData iconData = Icons.money;
    Color iconColor = Colors.green;
    
    if (paymentMethod.toLowerCase().contains('qris') || paymentMethod.toLowerCase().contains('transfer')) {
      iconData = Icons.qr_code;
      iconColor = Colors.purple;
    } else if (paymentMethod.toLowerCase().contains('hutang')) {
      iconData = Icons.hourglass_bottom;
      iconColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Text(
          formatRupiah(item['grand_total'] ?? 0),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(customerName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
            Text(
              "${DateFormat('HH:mm').format(date)} • $paymentMethod",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          // Navigasi ke detail struk bisa ditambahkan di sini
        },
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const SkeletonContainer(width: 45, height: 45, borderRadius: 25),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonContainer(width: 120, height: 16),
                  SizedBox(height: 8),
                  SkeletonContainer(width: 80, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Belum ada transaksi", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 4),
          const Text("Coba ubah tanggal filter", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}