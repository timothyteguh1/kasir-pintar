import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpensesPage extends StatefulWidget {
  final VoidCallback? onBack; 

  const ExpensesPage({super.key, this.onBack});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  // Variabel Data
  List<Map<String, dynamic>> _allExpenses = [];
  List<String> _supplierList = []; 
  bool _isLoading = true;
  String? _errorMessage;
  
  // Statistik
  double _totalExpenseRange = 0;
  double _stockExpense = 0;
  double _opsExpense = 0;

  // Default: 7 Hari Terakhir (Supaya lebih cepat load awalnya/Eager Loading feel)
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)), 
    end: DateTime.now()
  );

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchSuppliers();
  }

  Future<void> _fetchSuppliers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('suppliers').get();
      if (mounted) {
        setState(() {
          _supplierList = snap.docs
              .map((doc) => doc.data().containsKey('name') ? doc['name'].toString() : '')
              .where((name) => name.isNotEmpty)
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Gagal ambil supplier: $e");
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulasi delay sedikit (opsional) agar skeleton terlihat (UX feel)
    // await Future.delayed(const Duration(milliseconds: 500)); 

    DateTime start = DateTime(_selectedRange.start.year, _selectedRange.start.month, _selectedRange.start.day);
    DateTime end = DateTime(_selectedRange.end.year, _selectedRange.end.month, _selectedRange.end.day, 23, 59, 59);

    try {
      List<Map<String, dynamic>> tempData = [];
      double tempStock = 0;
      double tempOps = 0;

      // 1. FETCH PURCHASES
      try {
        final purchaseSnap = await FirebaseFirestore.instance
            .collection('purchases')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .get();

        for (var doc in purchaseSnap.docs) {
          var data = doc.data();
          double amount = (data['grand_total'] is int) 
              ? (data['grand_total'] as int).toDouble() 
              : (data['grand_total'] as double? ?? 0.0);
          
          tempStock += amount;
          
          tempData.add({
            'type': 'STOK',
            'title': "Belanja Stok",
            'supplier': data['supplier'] ?? 'Umum',
            'amount': amount,
            'date': (data['date'] as Timestamp).toDate(),
            'note': "${data['total_items'] ?? 0} Item",
            'category': 'Pembelian Stok',
            'color': Colors.blue,
          });
        }
      } catch (e) { debugPrint("Error purchases: $e"); }

      // 2. FETCH EXPENSES
      try {
        final expenseSnap = await FirebaseFirestore.instance
            .collection('expenses')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .get();

        for (var doc in expenseSnap.docs) {
          var data = doc.data();
          double amount = (data['amount'] is int) 
              ? (data['amount'] as int).toDouble() 
              : (data['amount'] as double? ?? 0.0);
          
          tempOps += amount;

          tempData.add({
            'type': 'OPS',
            'title': data['name'] ?? 'Pengeluaran',
            'supplier': data['supplier'],
            'amount': amount,
            'date': (data['date'] as Timestamp).toDate(),
            'note': data['note'] ?? '-',
            'category': data['category'] ?? 'Lain-lain',
            'color': _getCategoryColor(data['category']),
          });
        }
      } catch (e) { debugPrint("Error expenses: $e"); }

      // Sort Descending
      tempData.sort((a, b) => b['date'].compareTo(a['date']));

      if (mounted) {
        setState(() {
          _allExpenses = tempData;
          _stockExpense = tempStock;
          _opsExpense = tempOps;
          _totalExpenseRange = tempStock + tempOps;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = "Gagal memuat: $e"; });
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Bahan Baku': return Colors.orange;
      case 'Operasional': return Colors.red;
      case 'Gaji': return Colors.purple;
      default: return Colors.grey;
    }
  }

  // --- DIALOG INPUT ---
  void _showAddExpenseDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? selectedSupplier; 
    String selectedCategory = "Operasional";
    final List<String> categories = ["Bahan Baku", "Operasional", "Gaji", "Perlengkapan", "Lain-lain"];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Catat Pengeluaran"),
        content: SizedBox(
          width: double.maxFinite, 
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => selectedCategory = val!,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Nama Pengeluaran", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue val) {
                    if (val.text == '') return const Iterable<String>.empty();
                    return _supplierList.where((opt) => opt.toLowerCase().contains(val.text.toLowerCase()));
                  },
                  onSelected: (val) => selectedSupplier = val,
                  fieldViewBuilder: (ctx, controller, node, _) {
                    return TextField(
                      controller: controller, focusNode: node,
                      decoration: const InputDecoration(labelText: "Supplier (Opsional)", border: OutlineInputBorder(), suffixIcon: Icon(Icons.store)),
                      onChanged: (val) => selectedSupplier = val,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Nominal (Rp)", prefixText: "Rp ", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: "Catatan", border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || amountController.text.isEmpty) return;
              int amount = int.tryParse(amountController.text.replaceAll('.', '')) ?? 0;
              await FirebaseFirestore.instance.collection('expenses').add({
                'date': Timestamp.now(),
                'category': selectedCategory,
                'name': nameController.text,
                'supplier': selectedSupplier,
                'amount': amount,
                'note': noteController.text,
              });
              if (mounted) { Navigator.pop(context); _fetchData(); }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Colors.red, onPrimary: Colors.white)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedRange = picked);
      _fetchData();
    }
  }

  String formatRupiah(num number) => NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);

  // --- HELPERS UNTUK GROUPING ---
  String _getGroupDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final check = DateTime(date.year, date.month, date.day);

    if (check == today) return "Hari Ini";
    if (check == yesterday) return "Kemarin";
    return DateFormat('EEEE, dd MMMM', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Background sedikit lebih terang
      appBar: AppBar(
        title: const Text("Pengeluaran", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.date_range, color: Colors.blue), onPressed: _pickDateRange)
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Biaya Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // --- HEADER STATISTIK ---
          // Tidak perlu skeleton di sini karena biasanya cepat, tapi kita kasih animasi fade
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  "Total Biaya ${_selectedRange.duration.inDays + 1} Hari Terakhir",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                _isLoading 
                  ? Container(height: 40, width: 200, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)))
                  : Text(
                      formatRupiah(_totalExpenseRange),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                const SizedBox(height: 20),
                
                // Grafik batang sederhana
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        if (_totalExpenseRange > 0) ...[
                          Expanded(
                            flex: _stockExpense > 0 ? _stockExpense.toInt() : 0,
                            child: Container(color: Colors.blue),
                          ),
                          Expanded(
                            flex: _opsExpense > 0 ? _opsExpense.toInt() : 0,
                            child: Container(color: Colors.orange),
                          ),
                        ] else 
                          Expanded(child: Container(color: Colors.grey[200])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegend("Stok Produk", _stockExpense, Colors.blue),
                    _buildLegend("Operasional", _opsExpense, Colors.orange),
                  ],
                ),
              ],
            ),
          ),

          // --- ISI LIST (GROUPED) ---
          Expanded(
            child: _isLoading
                ? _buildSkeletonLoading() // TAMPILKAN SKELETON SAAT LOADING
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _allExpenses.isEmpty
                        ? _buildEmptyState() // TAMPILKAN STATE KOSONG YANG CANTIK
                        : _buildGroupedList(), // TAMPILKAN DATA YANG SUDAH DI-GROUP
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6, // Simulasi 6 item dummy
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(width: 45, height: 45, decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 12, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
              Container(width: 80, height: 16, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Aman! Tidak ada pengeluaran.", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text("Coba ubah filter tanggal di pojok kanan atas", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    // 1. Grouping Data
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var item in _allExpenses) {
      String key = _getGroupDate(item['date']);
      if (grouped[key] == null) grouped[key] = [];
      grouped[key]!.add(item);
    }

    // 2. Build ListView
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        String dateKey = grouped.keys.elementAt(index);
        List<Map<String, dynamic>> items = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER TANGGAL
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text(
                dateKey.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.0),
              ),
            ),
            // LIST ITEMS DI TANGGAL TERSEBUT
            ...items.map((item) => _buildExpenseItem(item)),
          ],
        );
      },
    );
  }

  Widget _buildExpenseItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (item['color'] as Color).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            item['type'] == 'STOK' ? Icons.inventory_2 : Icons.monetization_on,
            color: item['color'],
            size: 20,
          ),
        ),
        title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['supplier'] != null && item['supplier'] != '')
              Text(item['supplier'], style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(
              "${DateFormat('HH:mm').format(item['date'])} • ${item['category']}",
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            if (item['note'] != '-' && item['note'] != null)
              Text("\"${item['note']}\"", style: TextStyle(color: Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: Text(
          formatRupiah(item['amount']),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildLegend(String label, double amount, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(formatRupiah(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}