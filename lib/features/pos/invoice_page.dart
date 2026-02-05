import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvoicePage extends StatelessWidget {
  final Map<String, dynamic> transactionData;
  final VoidCallback onBackToHome;

  const InvoicePage({
    super.key,
    required this.transactionData,
    required this.onBackToHome,
  });

  String formatRupiah(int number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  String formatDate(dynamic dateData) {
    if (dateData == null) return "-";
    if (dateData is Timestamp) {
      return DateFormat('EEEE, d-MMM-yy HH:mm', 'id_ID').format(dateData.toDate());
    }
    return "-";
  }

  @override
  Widget build(BuildContext context) {
    final items = transactionData['items'] as List<dynamic>;
    final bool isPaid = transactionData['is_paid'] ?? true;

    // --- UPDATE PENTING: PopScope ---
    // Ini gunanya menangkap tombol BACK di HP.
    // Supaya walau di-back pakai tombol HP, keranjang tetap dikosongkan.
    return PopScope(
      canPop: false, // Matikan fungsi back bawaan
      onPopInvoked: (didPop) {
        if (didPop) return;
        onBackToHome(); // Paksa jalankan fungsi "Baru" (Clear Cart)
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("Invoice Transaksi"),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: onBackToHome, // Tombol Silang -> Clear Cart
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // KOP SURAT
                      const Text("Kasir Pintar Toti", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text("Jl. Sukses Selalu No. 99", style: TextStyle(color: Colors.grey)),
                      const Text("0812-3456-7890", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),
                      const Divider(thickness: 2),
                      
                      // META DATA
                      const SizedBox(height: 10),
                      Text("ID: ${transactionData['invoice_no']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      _buildRowDetail("Tanggal", formatDate(transactionData['date'])),
                      _buildRowDetail("Kasir", "Admin"),
                      _buildRowDetail("Customer", transactionData['customer_name']),
                      if (!isPaid)
                        _buildRowDetail("Jatuh Tempo", formatDate(transactionData['due_date']), isRed: true),
                      
                      _buildRowDetail("Status", isPaid ? "LUNAS" : "BELUM LUNAS", isBold: true, isRed: !isPaid),
                      
                      if (transactionData['start_date'] != null)
                        _buildRowDetail("Tgl Terima", formatDate(transactionData['start_date'])),
                      if (transactionData['end_date'] != null)
                        _buildRowDetail("Tgl Selesai", formatDate(transactionData['end_date'])),

                      const SizedBox(height: 20),
                      const Divider(),
                      
                      // PRODUCT LIST
                      const Align(alignment: Alignment.centerLeft, child: Text("Product List", style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(height: 10),
                      
                      ...items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['product_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("${item['qty']}x @${formatRupiah(item['sell_price'])}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            Text(formatRupiah(item['sell_price'] * item['qty']), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),

                      const SizedBox(height: 20),
                      const Divider(),

                      // FOOTER TOTAL
                      _buildRowDetail("Subtotal", formatRupiah(transactionData['subtotal'])),
                      if (transactionData['discount'] > 0)
                        _buildRowDetail("Diskon", "- ${formatRupiah(transactionData['discount'])}", isRed: true),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.blue.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Grand Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                            Text(formatRupiah(transactionData['grand_total']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRowDetail("Bayar (${transactionData['payment_method']})", formatRupiah(transactionData['pay_amount'])),
                      
                      if (isPaid)
                        _buildRowDetail("Kembalian", formatRupiah(transactionData['change']))
                      else
                        _buildRowDetail("Sisa Hutang", formatRupiah(transactionData['remaining_debt']), isRed: true),
                        
                      if (transactionData['payment_detail'] != null)
                         _buildRowDetail("Info", transactionData['payment_detail']),
                    ],
                  ),
                ),
              ),
            ),

            // TOMBOL AKSI
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(Icons.print, "Print", () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Print Segera Hadir!")));
                  }),
                  _buildActionButton(Icons.share, "Share", () {}),
                  // Tombol BARU -> Clear Cart
                  _buildActionButton(Icons.receipt_long, "Baru", onBackToHome), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowDetail(String label, String value, {bool isBold = false, bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isRed ? Colors.red : Colors.black,
          )),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[700]),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }
}