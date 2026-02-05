import 'package:flutter/material.dart';
import 'package:kasir_pintar_toti/features/reports/sales_transaction_page.dart';

class SalesReportPage extends StatelessWidget {
  final VoidCallback onBack;

  const SalesReportPage({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Kembali ke warna tema project
      appBar: AppBar(
        title: const Text("Menu Laporan", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black, // Teks hitam agar bersih
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: onBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Kecil
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "ANALISA BISNIS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
          ),

          // 1. PENJUALAN PRODUK
          _buildReportCard(
            context,
            title: "Penjualan Produk",
            subtitle: "Analisa barang terlaris (Best Seller)",
            icon: Icons.pie_chart,
            color: Colors.orange,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Segera Hadir: Laporan Produk")));
            },
          ),
          
          const SizedBox(height: 16),

          // 2. RIWAYAT TRANSAKSI (Sudah Jadi)
          _buildReportCard(
            context,
            title: "Riwayat Transaksi",
            subtitle: "Cek invoice & status pembayaran",
            icon: Icons.receipt_long_rounded,
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SalesTransactionPage()),
              );
            },
          ),

          const SizedBox(height: 16),

          // 3. KEUANGAN (Laba Rugi)
          _buildReportCard(
            context,
            title: "Laba & Rugi",
            subtitle: "Total Pendapatan - Modal (HPP)",
            icon: Icons.account_balance_wallet,
            color: Colors.green,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Segera Hadir: Laba Rugi")));
            },
          ),

          const SizedBox(height: 24),
          
          // Header Section 2
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "INVENTORI & STOK",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
          ),

          // 4. STOK MASUK
          _buildReportCard(
            context,
            title: "Pembelian Stok",
            subtitle: "Catat barang masuk (Kulakan)",
            icon: Icons.inventory,
            color: Colors.purple,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Segera Hadir: Stok")));
            },
          ),
          
          const SizedBox(height: 16),

          // 5. DEPOSIT
          _buildReportCard(
            context,
            title: "Deposit Pelanggan",
            subtitle: "Kelola saldo simpanan member",
            icon: Icons.savings,
            color: Colors.teal,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Segera Hadir: Deposit")));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Sudut melengkung khas project kita
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05), // Shadow halus
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Ikon dengan Background Soft
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1), // Warna soft (transparan)
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                
                const SizedBox(width: 16),
                
                // Teks Judul & Subjudul
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                
                // Panah Kanan
                Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}