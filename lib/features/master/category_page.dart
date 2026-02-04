import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late Future<QuerySnapshot> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _dataFuture = FirebaseFirestore.instance.collection('categories').orderBy('name').get();
    });
  }

  // UPDATE: Fungsi Dialog jadi serbaguna (Bisa Tambah, Bisa Edit)
  void showFormDialog({String? id, String? currentName}) {
    final controller = TextEditingController(text: currentName ?? ''); // Isi otomatis kalau Edit
    final bool isEditing = id != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit Kategori" : "Tambah Kategori"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nama Kategori (mis: Minuman)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                
                if (isEditing) {
                  // LOGIKA UPDATE
                  await FirebaseFirestore.instance.collection('categories').doc(id).update({
                    'name': controller.text,
                  });
                } else {
                  // LOGIKA TAMBAH BARU
                  await FirebaseFirestore.instance.collection('categories').add({
                    'name': controller.text,
                    'created_at': DateTime.now(),
                  });
                }

                _refreshData();
                if (mounted) {
                  showTopSnackBar(
                    Overlay.of(context), 
                    CustomSnackBar.success(message: isEditing ? "Kategori Diupdate" : "Kategori Disimpan")
                  );
                }
              }
            },
            child: Text(isEditing ? "Update" : "Simpan"),
          ),
        ],
      ),
    );
  }

  void deleteData(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus?"),
        content: const Text("Data ini akan dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseFirestore.instance.collection('categories').doc(id).delete().then((_) {
                _refreshData();
                showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: "Dihapus"));
              });
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showFormDialog(), // Mode Tambah (Tanpa parameter)
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Belum ada kategori"));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index];
              return ListTile(
                leading: CircleAvatar(backgroundColor: Colors.purple.shade50, child: const Icon(Icons.category, color: Colors.purple)),
                title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TOMBOL EDIT
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => showFormDialog(id: data.id, currentName: data['name']),
                    ),
                    // TOMBOL HAPUS
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteData(data.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}