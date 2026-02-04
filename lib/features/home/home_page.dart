import 'dart:convert'; // Wajib: Ubah Gambar ke Teks
import 'dart:io';
import 'dart:typed_data'; // Wajib: Olah data gambar
import 'package:cloud_firestore/cloud_firestore.dart'; // Wajib: Database
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Wajib: Ambil gambar
import 'package:kasir_pintar_toti/features/auth/login_page.dart';
import 'package:kasir_pintar_toti/features/products/add_product_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  
  // --- STATE UNTUK FOTO PROFIL ---
  bool isUploading = false;
  Uint8List? photoBytes; // Variabel penampung foto dari database

  @override
  void initState() {
    super.initState();
    // Saat aplikasi mulai, langsung cek database apakah user punya foto custom?
    _loadProfilePicture();
  }

  // 1. FUNGSI LOAD FOTO DARI DATABASE (Firestore)
  Future<void> _loadProfilePicture() async {
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      
      // Jika ada data 'photo_base64', kita ambil dan ubah jadi gambar
      if (doc.exists && doc.data()!.containsKey('photo_base64')) {
        String base64String = doc.get('photo_base64');
        setState(() {
          photoBytes = base64Decode(base64String);
        });
      }
    } catch (e) {
      debugPrint("Gagal load foto: $e");
    }
  }

  // 2. FUNGSI UPLOAD FOTO (Kompres & Simpan ke Database)
  Future<void> changeProfilePicture() async {
    final picker = ImagePicker();
    
    // Pilih gambar & KOMPRES JADI KECIL (Quality 20 biar muat di DB Gratisan)
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 20, // Kualitas diturunkan jadi 20%
      maxWidth: 512,    // Lebar diperkecil
    );
    
    if (pickedFile == null) return;

    setState(() => isUploading = true);

    try {
      // Baca file jadi bytes
      final bytes = await File(pickedFile.path).readAsBytes();
      
      // Ubah jadi Teks Panjang (Base64)
      String base64Image = base64Encode(bytes);

      // Simpan ke Firestore Database (Gratis, tidak butuh Storage Billing)
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'email': user!.email,
        'name': user!.displayName,
        'photo_base64': base64Image, // Ini fotonya disimpan sebagai teks
        'last_updated': DateTime.now().toString(),
      }, SetOptions(merge: true));

      // Tampilkan langsung di layar
      setState(() {
        photoBytes = bytes;
      });

      if (mounted) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: "Foto Profil Berhasil Disimpan!"));
      }

    } catch (e) {
      if (mounted) {
        showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: "Gagal Simpan: $e"));
      }
    } finally {
      setState(() => isUploading = false);
    }
  }

  // --- FUNGSI LOGOUT ---
  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      debugPrint("Google Logout dilewati: $e");
    }
    
    await FirebaseAuth.instance.signOut();
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // Widget Helper Menu Grid
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
      backgroundColor: Colors.grey[50], 
      
      // APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5), 
        elevation: 0,
        title: const Text("Kasir Toti PRO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Keluar Aplikasi",
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // HEADER BIRU
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
                  // --- PROFIL USER (LOGIKA BASE64 + UI LAMA) ---
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : changeProfilePicture, // Bisa diklik
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              // Logika Tampilan:
                              // 1. Cek photoBytes (dari database) -> Prioritas Utama
                              // 2. Cek photoURL (dari Google Login)
                              // 3. Pakai Default (Kartun)
                              backgroundImage: photoBytes != null
                                  ? MemoryImage(photoBytes!) as ImageProvider
                                  : NetworkImage(
                                      (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                                          ? user!.photoURL!
                                          : "https://i.pravatar.cc/150", 
                                    ),
                              child: isUploading 
                                ? const CircularProgressIndicator(strokeWidth: 2) 
                                : null,
                            ),
                            // Ikon Kamera Kecil
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.blue),
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
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

                  // KARTU RINGKASAN
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF9800), 
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
                        Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
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
                              Container(height: 40, width: 1, color: Colors.grey[300]),
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
                        Material(
                          color: Colors.red[50],
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                          child: InkWell(
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                            onTap: () {
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

            // MENU GRID
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
                    // Navigasi ke Halaman Tambah Produk (TETAP ADA)
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
              const SizedBox(width: 48), 
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