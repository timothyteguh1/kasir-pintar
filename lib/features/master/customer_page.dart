import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class CustomerPage extends StatefulWidget {
  const CustomerPage({super.key});

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  late Future<QuerySnapshot> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _dataFuture = FirebaseFirestore.instance.collection('customers').orderBy('name').get();
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
        title: Text(isEditing ? "Edit Pelanggan" : "Tambah Pelanggan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: "Nama Pelanggan")),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: "No. WhatsApp"), keyboardType: TextInputType.phone),
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
                  await FirebaseFirestore.instance.collection('customers').doc(id).update({
                    'name': nameCtrl.text,
                    'phone': phoneCtrl.text,
                  });
                } else {
                  // CREATE
                  await FirebaseFirestore.instance.collection('customers').add({
                    'name': nameCtrl.text,
                    'phone': phoneCtrl.text,
                    'created_at': DateTime.now(),
                  });
                }

                _refreshData();
                if (mounted) showTopSnackBar(Overlay.of(context), CustomSnackBar.success(message: isEditing ? "Pelanggan Diupdate" : "Pelanggan Disimpan"));
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
        content: const Text("Yakin hapus pelanggan ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseFirestore.instance.collection('customers').doc(id).delete().then((_) {
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
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Belum ada pelanggan"));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index];
              return ListTile(
                leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.person, color: Colors.blue)),
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