import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kasir_pintar_toti/features/auth/login_page.dart';
import 'package:kasir_pintar_toti/features/products/add_product_page.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;

  // --- FUNGSI LOGOUT (SUDAH DIPERBAIKI) ---
  // Aman untuk Windows & Android
  Future<void> logout() async {
    // 1. Coba Logout Google (Khusus Mobile)
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      // Jika error (misal di Windows), kita abaikan saja & lanjut logout Firebase
      debugPrint("Google Logout dilewati: $e");
    }

    // 2. Logout Firebase (Wajib)
    await FirebaseAuth.instance.signOut();

    // 3. Pindah ke Halaman Login
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // Widget Helper untuk Membuat Item Menu (Grid)
  Widget _buildMenuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Background abu muda bersih

      // HEADER BIRU
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5), // Biru POS
        elevation: 0,
        title: const Text("Kasir Toti PRO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: logout, // Panggil fungsi logout yang sudah diperbaiki
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Keluar Aplikasi",
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // BAGIAN DASHBOARD (Header Melengkung)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // Profil Singkat
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(user?.photoURL ?? "https://i.pravatar.cc/150"),
                        radius: 20,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Halo, ${user?.displayName ?? 'Admin'}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Text(
                            "Toko Cabang Surabaya",
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // CARD RINGKASAN (Omzet & Piutang)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header Kuning (Judul)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF9800), // Oranye Cerah
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Penjualan Hari Ini", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Icon(Icons.calendar_today, color: Colors.white, size: 16),
                            ],
                          ),
                        ),

                        // Isi Data (Omzet & Transaksi)
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Total Omzet
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Total Omzet", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 5),
                                  Text(
                                    "Rp 0,-",
                                    style: TextStyle(color: Colors.blue[700], fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              // Garis Tengah
                              Container(height: 40, width: 1, color: Colors.grey[300]),
                              // Jumlah Transaksi
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text("Transaksi", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  SizedBox(height: 5),
                                  Text(
                                    "0",
                                    style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Footer Merah (Piutang) - BISA DIKLIK
                        Material(
                          color: Colors.red[50], // Background merah muda
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                          child: InkWell(
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                            onTap: () {
                              // Aksi saat diklik
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Menu Piutang Segera Hadir!")),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Belum ada piutang jatuh tempo",
                                    style: TextStyle(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.chevron_right, color: Colors.red[800], size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // MENU GRID ICON
            Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 20,
                crossAxisSpacing: 15,
                childAspectRatio: 0.8,
                children: [
                  _buildMenuItem("Kasir", Icons.point_of_sale, Colors.blue, () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menu Kasir Segera Hadir!")));
                  }),
                  _buildMenuItem("Produk", Icons.inventory_2, Colors.orange, () {
                    // Navigasi ke Halaman Tambah Produk
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()));
                  }),
                  _buildMenuItem("Laporan", Icons.bar_chart, Colors.purple, () {}),
                  _buildMenuItem("Riwayat", Icons.history, Colors.green, () {}),
                  _buildMenuItem("Pelanggan", Icons.people, Colors.teal, () {}),
                  _buildMenuItem("Pengeluaran", Icons.money_off, Colors.red, () {}),
                  _buildMenuItem("Pegawai", Icons.badge, Colors.indigo, () {}),
                  _buildMenuItem("Setting", Icons.settings, Colors.grey, () {}),
                ],
              ),
            ),
          ],
        ),
      ),

      // BOTTOM NAVIGATION BAR
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(icon: const Icon(Icons.home, color: Colors.blue), onPressed: () {}),
              IconButton(icon: const Icon(Icons.receipt_long, color: Colors.grey), onPressed: () {}),
              const SizedBox(width: 48), // Spasi untuk tombol tengah
              IconButton(icon: const Icon(Icons.wallet, color: Colors.grey), onPressed: () {}),
              IconButton(icon: const Icon(Icons.person, color: Colors.grey), onPressed: () {}),
            ],
          ),
        ),
      ),

      // TOMBOL TENGAH (QR SCAN)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mode Scan Cepat!")));
        },
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 4,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
      ),
    );
  }
}