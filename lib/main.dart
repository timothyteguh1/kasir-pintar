// ... import di atas biarkan saja ...
import 'package:firebase_auth/firebase_auth.dart'; // Tambah ini
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/login_page.dart'; // Tambah ini
import 'features/home/home_page.dart';  // Tambah ini
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // --- 2. TAMBAHKAN BARIS INI (WAJIB) ---
  // Ini menyiapkan format tanggal/mata uang Indonesia sebelum aplikasi jalan
  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kasir Toti',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // SATPAM PINTAR (StreamBuilder)
      // Dia memantau status login secara real-time
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Jika User Login -> Masuk Home
          if (snapshot.hasData) {
            return const HomePage();
          }
          // 2. Jika User Belum Login -> Masuk Login Page
          return const LoginPage();
        },
      ),
    );
  }
}