import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  late Future<QuerySnapshot> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _dataFuture = FirebaseFirestore.instance.collection('suppliers').orderBy('name').get();
    });
  }

  // UPDATE: Dialog Terima Parameter untuk Edit
  void showFormDialog({String? id, String? currentName, String? currentPhone}) {
    final nameCtrl = TextEditingController(text: currentName ?? '');
    final phoneCtrl = TextEditingController(text: currentPhone ?? '');
    final bool isEditing = id != null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? "Edit Supplier" : "Tambah Supplier"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: "Nama PT / Toko")),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: "No. HP / Telp"), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                Navigator.pop(context);
                
                if (isEditing) {
                  // UPDATE
                  await FirebaseFirestore.instance.collection('suppliers').doc(id).update({
                    'name': nameCtrl.text,
                    'phone': phoneCtrl.text,
                  });
                } else {
                  // CREATE
                  await FirebaseFirestore.instance.collection('suppliers').add({
                    'name': nameCtrl.text,
                    'phone': phoneCtrl.text,
                    'created_at': DateTime.now(),
                  });
                }

                _refreshData();
                if (mounted) showTopSnackBar(Overlay.of(context), CustomSnackBar.success(message: isEditing ? "Supplier Diupdate" : "Supplier Disimpan"));
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
        content: const Text("Yakin hapus supplier ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseFirestore.instance.collection('suppliers').doc(id).delete().then((_) {
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
        onPressed: () => showFormDialog(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Belum ada supplier"));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index];
              return ListTile(
                leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(Icons.local_shipping, color: Colors.green)),
                title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['phone'] ?? '-'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => showFormDialog(id: data.id, currentName: data['name'], currentPhone: data['phone']),
                    ),
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