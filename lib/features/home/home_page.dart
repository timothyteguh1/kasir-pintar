import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Fungsi untuk Logout
  void logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    // Ambil data user yang sedang login
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kasir Toti"),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            tooltip: "Keluar",
          ),
        ],
      ),
      // ... kode atas sama ...
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.waving_hand, size: 50, color: Colors.orange),
            const SizedBox(height: 10),
            Text(
              // Mengambil Display Name yang tadi kita simpan saat Register
              "Halo, ${user?.displayName ?? 'Kasir'}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "Email: ${user?.email}",
              style: const TextStyle(color: Colors.grey),
            ),
            // ... kode bawah sama ...
            const SizedBox(height: 20),
            const Text("Menu Kasir akan muncul di sini nanti."),
          ],
        ),
      ),
    );
  }
}
