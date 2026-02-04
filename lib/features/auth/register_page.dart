import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kasir_pintar_toti/features/home/home_page.dart'; // Import Home Page
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool isLoading = false;
  bool isObscure = true; 

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      // 1. Buat User Baru
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 2. Simpan Nama ke Profil
      await userCredential.user!.updateDisplayName(nameController.text.trim());

      // 3. SUKSES -> PINDAH KE HOME (Hapus semua history balik ke login)
      if (mounted) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: "Pendaftaran Berhasil!"));
        
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false // Hapus tombol back, biar gak bisa balik ke register
        );
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
        child: SingleChildScrollView( 
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400), // Batasi lebar di Windows
            child: Form(
              key: _formKey, 
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
                    validator: (value) => (value == null || value.isEmpty) ? "Nama wajib diisi" : null,
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
                    validator: (value) => (value == null || !value.contains('@')) ? "Email tidak valid" : null,
                  ),
                  const SizedBox(height: 16),

                  // Input Password
                  TextFormField(
                    controller: passwordController,
                    obscureText: isObscure, 
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => isObscure = !isObscure),
                      ),
                    ),
                    validator: (value) => (value == null || value.length < 6) ? "Minimal 6 karakter" : null,
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
      ),
    );
  }
}