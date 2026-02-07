import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfitLossPage extends StatefulWidget {
  const ProfitLossPage({super.key});

  @override
  State<ProfitLossPage> createState() => _ProfitLossPageState();
}

class _ProfitLossPageState extends State<ProfitLossPage> {
  DateTimeRange? selectedDateRange;
  bool _isLoading = false;

  // Variabel Laporan
  double _grossSales = 0;   // Penjualan Kotor (Sebelum diskon)
  double _totalDiscount = 0; // Total Diskon diberikan
  double _netSales = 0;     // Penjualan Bersih (Uang diterima)
  double _totalCost = 0;    // HPP (Modal)
  double _grossProfit = 0;  // Laba Kotor (Net Sales - HPP)
  
  // Variabel Operasional (Placeholder untuk pengembangan nanti)
  final double _operationalCost = 0; 
  final double _tax = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default: Bulan Ini
    selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _calculateProfitLoss();
  }

  Future<void> _calculateProfitLoss() async {
    setState(() => _isLoading = true);
    
    double tempGrossSales = 0;
    double tempDiscount = 0;
    double tempCost = 0;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDateRange!.start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(selectedDateRange!.end))
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // 1. Ambil data transaksi
        double grandTotal = (data['grand_total'] ?? 0).toDouble();
        double discount = (data['discount'] ?? 0).toDouble();
        
        // Penjualan Kotor = Uang Masuk + Diskon yang diberikan
        tempGrossSales += (grandTotal + discount);
        tempDiscount += discount;

        // 2. Hitung Modal (HPP)
        if (data['items'] != null) {
          final items = data['items'] as List<dynamic>;
          for (var item in items) {
            final int qty = item['qty'] ?? 0;
            final int costPrice = item['cost_price'] ?? 0; 
            tempCost += (qty * costPrice);
          }
        }
      }

      if (mounted) {
        setState(() {
          _grossSales = tempGrossSales;
          _totalDiscount = tempDiscount;
          _netSales = tempGrossSales - tempDiscount; // Harusnya sama dengan total grand_total
          _totalCost = tempCost;
          _grossProfit = _netSales - tempCost;
        });
      }

    } catch (e) {
      debugPrint("Error calculating profit/loss: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String formatRupiah(num number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  Future<void> _pickDateRange() async {
    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: selectedDateRange,
    );

    if (newRange != null) {
      setState(() {
        selectedDateRange = DateTimeRange(
          start: newRange.start,
          end: DateTime(newRange.end.year, newRange.end.month, newRange.end.day, 23, 59, 59),
        );
      });
      _calculateProfitLoss();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hitung Laba Bersih Akhir
    double netProfitFinal = _grossProfit - _operationalCost - _tax;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7), // Abu-abu terang background
      appBar: AppBar(
        title: const Text("Laporan Laba Rugi", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // --- HEADER TANGGAL ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: InkWell(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Periode", style: TextStyle(color: Colors.grey[600])),
                    Row(
                      children: [
                        Text(
                          "${DateFormat('dd MMM').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange!.end)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 10),

          // --- ISI LAPORAN ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      
                      // KARTU 1: INCOME STATEMENT (PENDAPATAN)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            _buildSectionHeader("PEMASUKAN (INCOME)"),
                            _buildLineItem("Penjualan Kotor (Gross Sales)", _grossSales),
                            _buildLineItem("Diskon Transaksi", _totalDiscount, isNegative: true),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            _buildLineItem("Lain-lain / Pembulatan", 0), // Placeholder
                            
                            // TOTAL INCOME BAR
                            _buildTotalBar("TOTAL PENDAPATAN BERSIH", _netSales, Colors.blue),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // KARTU 2: COST OF GOODS SOLD (HPP)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
                        ),
                        child: Column(
                          children: [
                            _buildSectionHeader("PENGELUARAN (COST)"),
                            _buildLineItem("Harga Pokok Penjualan (HPP)", _totalCost, isNegative: true),
                            _buildLineItem("Biaya Operasional", _operationalCost, isNegative: true), // Placeholder
                            _buildLineItem("Pajak", _tax, isNegative: true), // Placeholder
                            
                            // TOTAL COST BAR
                            _buildTotalBar("TOTAL MODAL & BIAYA", _totalCost + _operationalCost + _tax, Colors.orange),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // KARTU 3: NET PROFIT (HASIL AKHIR)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: netProfitFinal >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFE53935), // Hijau / Merah
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (netProfitFinal >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "LABA BERSIH (NET PROFIT)",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              formatRupiah(netProfitFinal),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER UI ---

  // 1. Header Abu-abu kecil
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Text(
        title,
        style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  // 2. Baris Item Biasa
  Widget _buildLineItem(String label, double value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Text(
            (isNegative ? "- " : "") + formatRupiah(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isNegative ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 3. Bar Total Berwarna (Seperti Referensi)
  Widget _buildTotalBar(String label, double value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Text(
            formatRupiah(value),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}