import 'dart:convert'; // Wajib: Ubah Gambar ke Teks
import 'dart:io';
import 'dart:typed_data'; // Wajib: Olah data gambar
import 'package:cloud_firestore/cloud_firestore.dart'; // Wajib: Database
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Wajib: Ambil gambar
import 'package:kasir_pintar_toti/features/auth/login_page.dart';
// ignore: unused_import
import 'package:kasir_pintar_toti/features/products/product_list_page.dart'; // Wajib: Halaman List Produk
import 'package:kasir_pintar_toti/features/reports/sales_report_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:kasir_pintar_toti/features/master/master_data_page.dart';
import 'package:kasir_pintar_toti/features/pos/pos_page.dart';
import 'package:kasir_pintar_toti/features/reports/sales_transaction_page.dart'; // Untuk Riwayat
import 'package:kasir_pintar_toti/features/customers/customer_page.dart'; // Untuk Pelanggan
import 'package:kasir_pintar_toti/features/expenses/expenses_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;

  // --- STATE HALAMAN AKTIF ---
  Widget? _activePage;

  // --- STATE UNTUK FOTO PROFIL ---
  bool isUploading = false;
  Uint8List? photoBytes;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  // 1. FUNGSI LOAD FOTO DARI DATABASE (Firestore)
  Future<void> _loadProfilePicture() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
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

  // 2. FUNGSI UPLOAD FOTO
  Future<void> changeProfilePicture() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 20,
      maxWidth: 512,
    );

    if (pickedFile == null) return;

    setState(() => isUploading = true);

    try {
      final bytes = await File(pickedFile.path).readAsBytes();
      String base64Image = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'email': user!.email,
        'name': user!.displayName,
        'photo_base64': base64Image,
        'last_updated': DateTime.now().toString(),
      }, SetOptions(merge: true));

      setState(() {
        photoBytes = bytes;
      });

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.success(
            message: "Foto Profil Berhasil Disimpan!",
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          CustomSnackBar.error(message: "Gagal Simpan: $e"),
        );
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
  Widget _buildMenuItem(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- LOGIKA UTAMA: TAMPILKAN HALAMAN AKTIF ---
    if (_activePage != null) {
      return _activePage!;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],

      // APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        title: const Text(
          "Kasir Toti PRO",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
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
                  // --- PROFIL USER ---
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : changeProfilePicture,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              backgroundImage: photoBytes != null
                                  ? MemoryImage(photoBytes!) as ImageProvider
                                  : NetworkImage(
                                      (user?.photoURL != null &&
                                              user!.photoURL!.isNotEmpty)
                                          ? user!.photoURL!
                                          : "https://i.pravatar.cc/150",
                                    ),
                              child: isUploading
                                  ? const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Halo, ${user?.displayName ?? 'Admin'}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            "Toko Cabang Surabaya",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
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
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 15,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF9800),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(15),
                              topRight: Radius.circular(15),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  "Penjualan Hari Ini",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 16,
                              ),
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
                                  const Text(
                                    "Total Omzet",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "Rp 0,-",
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                height: 40,
                                width: 1,
                                color: Colors.grey[300],
                              ),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Transaksi",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    "0",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.red[50],
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          child: InkWell(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Menu Piutang Segera Hadir!"),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Belum ada piutang jatuh tempo",
                                    style: TextStyle(
                                      color: Colors.red[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.red[800],
                                    size: 18,
                                  ),
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
                childAspectRatio: 0.7,
                children: [
                  _buildMenuItem("Kasir", Icons.point_of_sale, Colors.blue, () {
                    setState(() {
                      _activePage = PosPage(
                        onBack: () {
                          setState(() => _activePage = null);
                        },
                      );
                    });
                  }),
                  _buildMenuItem(
                    "Produk",
                    Icons.inventory_2,
                    Colors.orange,
                    () {
                      setState(() {
                        _activePage = MasterDataPage(
                          onBack: () {
                            setState(() => _activePage = null);
                          },
                        );
                      });
                    },
                  ),
                  _buildMenuItem(
                    "Laporan",
                    Icons.bar_chart,
                    Colors.purple,
                    () {
                      setState(() {
                        _activePage = SalesReportPage(
                          onBack: () {
                            setState(() => _activePage = null);
                          },
                        );
                      });
                    },
                  ),
                  _buildMenuItem("Riwayat", Icons.history, Colors.green, () {
                    setState(() {
                      _activePage = SalesTransactionPage(
                        onBack: () => setState(() => _activePage = null),
                      );
                    });
                  }),
                  _buildMenuItem("Pelanggan", Icons.people, Colors.teal, () {
                    setState(() {
                      _activePage = CustomerPage(
                        onBack: () => setState(() => _activePage = null),
                      );
                    });
                  }),
                  _buildMenuItem(
                    "Pengeluaran",
                    Icons.money_off,
                    Colors.red,
                    () {
                      setState(() {
                        _activePage = ExpensesPage(
                          onBack: () => setState(() => _activePage = null),
                        );
                      });
                    },
                  ),
                  _buildMenuItem("Pegawai", Icons.badge, Colors.indigo, () {}),
                  _buildMenuItem("Setting", Icons.settings, Colors.grey, () {}),
                ],
              ),
            ),
          ],
        ),
      ),

      // --- [FIX] BOTTOM NAVIGATION BAR TANPA SHAPE ---
      bottomNavigationBar: BottomAppBar(
        color: Colors.white, // Hapus 'shape' notch di sini
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: Colors.blue),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.receipt_long, color: Colors.grey),
                onPressed: () {},
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: const Icon(Icons.wallet, color: Colors.grey),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.person, color: Colors.grey),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),

      // --- [FIX] FAB MELAYANG (MENCEGAH ERROR GEOMETRI) ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _activePage = PosPage(
              onBack: () {
                setState(() => _activePage = null);
              },
            );
          });
        },
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 4,
        child: const Icon(Icons.point_of_sale, color: Colors.white, size: 30),
      ),
    );
  }
}