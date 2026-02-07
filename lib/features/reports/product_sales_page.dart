import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Model data
class ProductStat {
  final String name;
  int qty;
  double totalRevenue;

  ProductStat({required this.name, required this.qty, required this.totalRevenue});
}

class ProductSalesPage extends StatefulWidget {
  const ProductSalesPage({super.key});

  @override
  State<ProductSalesPage> createState() => _ProductSalesPageState();
}

class _ProductSalesPageState extends State<ProductSalesPage> {
  DateTimeRange? selectedDateRange;
  bool _isLoading = false;
  List<ProductStat> _sortedProducts = [];
  int _totalItemsSold = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    _fetchAndAggregateData();
  }

  Future<void> _fetchAndAggregateData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDateRange!.start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(selectedDateRange!.end))
          .get();

      Map<String, ProductStat> tempMap = {};
      int totalQty = 0;
      double totalRev = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['items'] != null) {
          final items = data['items'] as List<dynamic>;
          for (var item in items) {
            String name = item['product_name'] ?? 'Tanpa Nama';
            int qty = item['qty'] ?? 0;
            int sellPrice = item['sell_price'] ?? 0;
            double revenue = (qty * sellPrice).toDouble();

            if (tempMap.containsKey(name)) {
              tempMap[name]!.qty += qty;
              tempMap[name]!.totalRevenue += revenue;
            } else {
              tempMap[name] = ProductStat(name: name, qty: qty, totalRevenue: revenue);
            }
            totalQty += qty;
            totalRev += revenue;
          }
        }
      }

      List<ProductStat> sortedList = tempMap.values.toList();
      sortedList.sort((a, b) => b.qty.compareTo(a.qty));
      
      if (mounted) {
        setState(() {
          _sortedProducts = sortedList;
          _totalItemsSold = totalQty;
          _totalRevenue = totalRev;
        });
      }
    } catch (e) {
      debugPrint("Error calculating product sales: $e");
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
      _fetchAndAggregateData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Penjualan Produk", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
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
          // --- FILTER TANGGAL ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: Colors.white,
            child: InkWell(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      "${DateFormat('dd MMM').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange!.end)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),

          // --- RINGKASAN DATA ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryBoxNew("Total Terjual", "$_totalItemsSold Item", Icons.shopping_cart, Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryBoxNew("Total Omzet", formatRupiah(_totalRevenue), Icons.payments, Colors.blue),
                ),
              ],
            ),
          ),

          // --- LIST PERINGKAT (BERSIH TANPA GARIS WARNA) ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sortedProducts.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        itemCount: _sortedProducts.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = _sortedProducts[index];
                          final int rank = index + 1;
                          
                          // --- WARNA BADGE ---
                          Color badgeColor = Colors.grey.shade200; 
                          Color textColor = Colors.grey.shade700;
                          
                          if (rank == 1) { badgeColor = const Color(0xFFFFD700); textColor = Colors.white; } // Emas
                          else if (rank == 2) { badgeColor = const Color(0xFFC0C0C0); textColor = Colors.white; } // Perak
                          else if (rank == 3) { badgeColor = const Color(0xFFCD7F32); textColor = Colors.white; } // Perunggu

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // --- BADGE RANKING (BULAT) ---
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    shape: BoxShape.circle,
                                    // Tambah shadow sedikit kalau Top 3 biar cantik
                                    boxShadow: rank <= 3 ? [BoxShadow(color: badgeColor.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2))] : null,
                                  ),
                                  child: Text(
                                    "#$rank",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // --- NAMA BARANG ---
                                Expanded(
                                  child: Text(
                                    product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // --- STATISTIK KANAN ---
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Jumlah Terjual
                                    Text(
                                      "${product.qty} Terjual",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                                    ),
                                    const SizedBox(height: 2),
                                    // Total Pendapatan
                                    Text(
                                      formatRupiah(product.totalRevenue),
                                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBoxNew(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_rounded, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text("Belum ada data penjualan", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}