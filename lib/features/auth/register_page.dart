import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controller untuk menangkap inputan
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  
  // Kunci Rahasia untuk Validasi Form
  final _formKey = GlobalKey<FormState>();
  
  bool isLoading = false;
  bool isObscure = true; // Status password tersembunyi/tidak

  Future<void> register() async {
    // 1. Cek apakah semua kotak isian sudah valid?
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // 2. Buat user di Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 3. PENTING: Simpan Nama Kasir ke Profil Firebase
      // Jadi nanti di Home bisa sapa: "Halo, Budi" bukan cuma email.
      await userCredential.user!.updateDisplayName(nameController.text.trim());

      if (mounted) {
        showTopSnackBar(
          Overlay.of(context),
          const CustomSnackBar.success(message: "Pendaftaran Berhasil! Silakan Login."),
        );
        Navigator.pop(context); // Kembali ke halaman Login
      }
    } on FirebaseAuthException catch (e) {
      String message = "Gagal Daftar.";
      if (e.code == 'email-already-in-use') message = "Email ini sudah terdaftar.";
      if (e.code == 'weak-password') message = "Password terlalu lemah (min 6 karakter).";
      
      if (mounted) {
        showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: message));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Kasir Baru")),
      body: Center(
        child: SingleChildScrollView( // Agar bisa discroll saat keyboard muncul
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey, // Pasang kunci validasi di sini
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add_alt_1, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  "Gabung Tim Kasir",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),

                // Input Nama
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Nama Lengkap",
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Nama wajib diisi";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Input Email
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) return "Email tidak valid";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Input Password dengan Mata Intip
                TextFormField(
                  controller: passwordController,
                  obscureText: isObscure, // Bisa berubah hidden/show
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          isObscure = !isObscure; // Balik status (hidden <-> show)
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) return "Minimal 6 karakter";
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Tombol Daftar
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: register,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("DAFTAR SEKARANG", style: TextStyle(fontSize: 16)),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}