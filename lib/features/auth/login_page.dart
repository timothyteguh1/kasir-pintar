import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Tetap pakai alias biar aman
import 'package:google_sign_in/google_sign_in.dart' as google_auth; 
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); 
  final google_auth.GoogleSignIn _googleSignIn = google_auth.GoogleSignIn();

  bool isLoading = false;
  bool isObscure = true;

  // --- FUNGSI LOGIN EMAIL ---
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    // Mulai Loading Full Screen
    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message = "Login Gagal.";
      if (e.code == 'user-not-found') message = "Email belum terdaftar.";
      if (e.code == 'wrong-password') message = "Password salah.";
      if (e.code == 'invalid-email') message = "Format email salah.";
      if (e.code == 'too-many-requests') message = "Terlalu banyak percobaan. Coba lagi nanti.";
      
      if (mounted) {
        showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: message));
      }
    } finally {
      // Stop Loading (Kalau sukses dia pindah halaman, kalau gagal dia stop loading)
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- FUNGSI LOGIN GOOGLE ---
  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final google_auth.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }
      final google_auth.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: e.message ?? "Gagal Login Google"));
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "Terjadi kesalahan sistem (Cek koneksi internet)"));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kita bungkus semuanya dengan STACK agar bisa menaruh Loading di lapisan paling atas
    return Scaffold(
      body: Stack(
        children: [
          // 1. LAPISAN BELAKANG (FORM LOGIN)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                // Tambahan: Membatasi lebar agar di Windows Fullscreen tidak terlalu lebar
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.storefront_rounded, size: 80, color: Colors.blue),
                      const SizedBox(height: 20),
                      const Text(
                        "Selamat Datang Kembali",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const Text(
                        "Kelola tokomu dengan lebih mudah",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 40),
                      
                      // Input Email Modern
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email",
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true, // Ada warna background
                          fillColor: Colors.grey.shade50,
                          enabled: !isLoading, // Matikan input saat loading
                        ),
                        validator: (value) => (value == null || !value.contains('@')) ? "Email tidak valid" : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Input Password Modern
                      TextFormField(
                        controller: passwordController,
                        obscureText: isObscure,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          enabled: !isLoading,
                          suffixIcon: IconButton(
                            icon: Icon(isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => isObscure = !isObscure),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? "Password wajib diisi" : null,
                      ),
                      const SizedBox(height: 24),

                      // Tombol Masuk dengan Hover Effect
                      SizedBox(
                        height: 50, // Tombol lebih tinggi biar gagah
                        child: ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              // Ganti warna saat di-hover mouse (Fitur Windows)
                              if (states.contains(WidgetState.hovered)) return Colors.blue.shade800;
                              if (states.contains(WidgetState.disabled)) return Colors.grey;
                              return Colors.blue;
                            }),
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            elevation: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.hovered)) return 6; // Bayangan naik saat hover
                              return 2;
                            }),
                          ),
                          child: const Text("MASUK SEKARANG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text("ATAU", style: TextStyle(color: Colors.grey, fontSize: 12))), Expanded(child: Divider())]),
                      const SizedBox(height: 24),

                      // Tombol Google dengan Hover Effect & GAMBAR PNG
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: isLoading ? null : signInWithGoogle,
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              // Efek background tipis saat hover
                              if (states.contains(WidgetState.hovered)) return Colors.blue.shade50;
                              return Colors.transparent;
                            }),
                            side: WidgetStateProperty.all(BorderSide(color: Colors.grey.shade300)),
                            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // PENTING: Link PNG agar tidak crash
                              Image.network('https://freesvg.org/img/1534129544.png', height: 24),
                              const SizedBox(width: 12),
                              const Text("Masuk dengan Google", style: TextStyle(fontSize: 16, color: Colors.black87)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                        child: const Text("Belum punya akun? Daftar Staff Baru"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. LAPISAN DEPAN (LOADING OVERLAY)
          // Ini yang bikin efek "Loading Scene"
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5), // Layar jadi gelap transparan
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white), // Spinner Putih
                    SizedBox(height: 20),
                    Text(
                      "Sedang Memproses...",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}