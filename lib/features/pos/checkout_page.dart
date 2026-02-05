import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import format tanggal Indo
import 'package:kasir_pintar_toti/models/cart_model.dart';
import 'package:kasir_pintar_toti/features/pos/invoice_page.dart'; // Import Invoice Page
import 'package:top_snackbar_flutter/custom_snack_bar.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> cartItems;
  final int subtotal;

  const CheckoutPage({super.key, required this.cartItems, required this.subtotal});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final discountController = TextEditingController();
  final payAmountController = TextEditingController();
  final startDateController = TextEditingController();
  final endDateController = TextEditingController();
  final dueDateController = TextEditingController();
  final refNoController = TextEditingController();

  String? selectedCustomerId;
  String selectedCustomerName = "Walk-In Customer"; 
  String paymentMethod = "Cash"; 
  List<Map<String, dynamic>> customers = [];
  
  String? selectedNonCashType;
  final List<String> nonCashOptions = [
    'QRIS', 'Transfer BCA', 'Transfer Mandiri', 'Transfer BRI', 'EDC BCA', 'GoPay', 'OVO', 'Dana'
  ];
  
  int discount = 0;
  int payAmount = 0;
  
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  DateTime? selectedDueDate;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null); // Inisialisasi format tanggal Indo
    _fetchCustomers();
    
    selectedStartDate = DateTime.now();
    startDateController.text = DateFormat('dd/MM/yyyy').format(selectedStartDate!);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePayAmount();
    });
  }

  void _updatePayAmount() {
    if (paymentMethod != "Hutang") {
      setState(() {
        payAmount = grandTotal;
        payAmountController.text = grandTotal.toString();
      });
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('customers').orderBy('name').get();
      setState(() {
        customers = snap.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
        }).toList();
        customers.insert(0, {'id': 'walk-in', 'name': 'Walk-In Customer (Umum)'});
      });
    } catch (e) {
      debugPrint("Gagal ambil pelanggan: $e");
    }
  }

  // --- LOGIC PIN OTORISASI (KEAMANAN) ---
  void _showPinDialog() {
    String inputPin = "";
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Otorisasi Supervisor"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Masukkan PIN untuk memberi diskon."),
            const SizedBox(height: 10),
            TextField(
              obscureText: true, // Sembunyikan angka
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: "PIN (Default: 123456)", counterText: ""),
              onChanged: (val) => inputPin = val,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Tutup Dialog PIN
              if (inputPin == "123456") {
                // JIKA PIN BENAR: Buka Dialog Input Diskon
                _showDiscountInputDialog();
              } else {
                // JIKA PIN SALAH
                if (mounted) showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "PIN Salah! Akses Ditolak."));
              }
            },
            child: const Text("Verifikasi"),
          ),
        ],
      ),
    );
  }

  void _showDiscountInputDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Masukkan Nominal Diskon"),
        content: TextField(
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: "Rp ", hintText: "0"),
          onChanged: (val) {
            // Update state di halaman induk
            setState(() {
              discount = int.tryParse(val.replaceAll('.', '')) ?? 0;
              discountController.text = discount.toString(); // Update tampilan textfield read-only
              _updatePayAmount(); // Recalculate total bayar
            });
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Selesai")),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isStart, bool isDue = false}) async {
    final now = DateTime.now();
    DateTime initialDate = now;
    DateTime firstDate = DateTime(2020);

    if (isDue) {
      firstDate = now; 
      initialDate = selectedDueDate ?? (selectedEndDate ?? now.add(const Duration(days: 7)));
    } else if (!isStart) {
      firstDate = selectedStartDate ?? now;
      initialDate = selectedEndDate ?? firstDate;
    } else {
      initialDate = selectedStartDate ?? now;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Colors.blue)),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        final formatted = DateFormat('dd/MM/yyyy').format(picked);
        if (isDue) {
          selectedDueDate = picked;
          dueDateController.text = formatted;
        } else if (isStart) {
          selectedStartDate = picked;
          startDateController.text = formatted;
          if (selectedEndDate != null && selectedEndDate!.isBefore(picked)) {
             selectedEndDate = null;
             endDateController.clear();
          }
        } else {
          selectedEndDate = picked;
          endDateController.text = formatted;
        }
      });
    }
  }

  Widget _buildQuickMoneyButton(int amount) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            payAmount = amount;
            payAmountController.text = amount.toString();
          });
        },
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: const BorderSide(color: Colors.blue),
        ),
        child: Text(formatRupiah(amount), style: const TextStyle(color: Colors.blue, fontSize: 12)),
      ),
    );
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context, 
      builder: (dialogContext) => AlertDialog(
        title: const Text("Tambah Pelanggan Baru"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nama Pelanggan")),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "No. HP/WA"), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              Navigator.pop(dialogContext);

              try {
                final ref = await FirebaseFirestore.instance.collection('customers').add({
                  'name': nameCtrl.text,
                  'phone': phoneCtrl.text,
                  'created_at': DateTime.now(),
                });
                await _fetchCustomers();
                
                if (!mounted) return;
                setState(() {
                  selectedCustomerId = ref.id;
                  selectedCustomerName = nameCtrl.text;
                });

                if (mounted) showTopSnackBar(Overlay.of(context), const CustomSnackBar.success(message: "Pelanggan Baru Dipilih!"));
              } catch (e) {
                debugPrint("Error: $e");
              }
            },
            child: const Text("Simpan & Pilih"),
          ),
        ],
      ),
    );
  }

  String formatRupiah(int number) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  int get grandTotal => (widget.subtotal - discount) < 0 ? 0 : (widget.subtotal - discount);
  
  int get change {
    if (paymentMethod == "Hutang") return 0;
    return payAmount - grandTotal;
  }

  Future<void> _processTransaction() async {
    // 1. Validasi Pembayaran
    if (paymentMethod != "Hutang" && payAmount < grandTotal) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "Uang pembayaran kurang!"));
      return;
    }

    if (paymentMethod == "Non-Cash" && selectedNonCashType == null) {
      showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "Pilih jenis pembayaran Non-Cash!"));
      return;
    }

    // 2. Validasi Hutang
    if (paymentMethod == "Hutang") {
      if (selectedCustomerId == 'walk-in' || selectedCustomerId == null) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "Hutang wajib pilih Pelanggan terdaftar!"));
        return;
      }
      if (selectedDueDate == null) {
        showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "Tentukan Tanggal Jatuh Tempo tagihan!"));
        return;
      }
      if (selectedEndDate != null) {
        DateTime end = DateTime(selectedEndDate!.year, selectedEndDate!.month, selectedEndDate!.day);
        DateTime due = DateTime(selectedDueDate!.year, selectedDueDate!.month, selectedDueDate!.day);
        if (due.isBefore(end)) {
           showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "Tanggal Tagihan tidak boleh sebelum Tanggal Selesai!"));
           return;
        }
      }
    }

    // 3. Validasi Tanggal
    if (selectedEndDate != null && selectedStartDate != null) {
      DateTime start = DateTime(selectedStartDate!.year, selectedStartDate!.month, selectedStartDate!.day);
      DateTime end = DateTime(selectedEndDate!.year, selectedEndDate!.month, selectedEndDate!.day);
      if (start.isAfter(end)) {
         showTopSnackBar(Overlay.of(context), const CustomSnackBar.error(message: "Tanggal Mulai tidak boleh melewati Tanggal Selesai!"));
         return;
      }
    }

    // Tampilkan Loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final batch = FirebaseFirestore.instance.batch();
      final transactionRef = FirebaseFirestore.instance.collection('transactions').doc();
      
      // SIAPKAN DATA (Ini yang nanti kita kirim balik ke PosPage)
      final transactionData = {
        'invoice_no': "INV-${DateTime.now().millisecondsSinceEpoch}",
        'date': Timestamp.now(),
        'start_date': selectedStartDate != null ? Timestamp.fromDate(selectedStartDate!) : null,
        'end_date': selectedEndDate != null ? Timestamp.fromDate(selectedEndDate!) : null,
        'due_date': selectedDueDate != null ? Timestamp.fromDate(selectedDueDate!) : null,
        'customer_name': selectedCustomerName,
        'customer_id': selectedCustomerId,
        'payment_method': paymentMethod,
        'payment_detail': paymentMethod == 'Non-Cash' ? selectedNonCashType : null,
        'payment_note': refNoController.text,
        'items': widget.cartItems.map((item) => {
          'product_id': item.product.id,
          'product_name': item.product.name,
          'qty': item.qty,
          'cost_price': item.product.costPrice,
          'sell_price': item.product.price,
        }).toList(),
        'subtotal': widget.subtotal,
        'discount': discount,
        'grand_total': grandTotal,
        'pay_amount': payAmount,
        'change': change,
        'is_paid': paymentMethod != "Hutang", 
        'remaining_debt': paymentMethod == "Hutang" ? (grandTotal - payAmount) : 0,
      };

      // Simpan ke Database
      batch.set(transactionRef, transactionData);

      for (var item in widget.cartItems) {
        final productRef = FirebaseFirestore.instance.collection('products').doc(item.product.id);
        batch.update(productRef, {
          'stock': FieldValue.increment(-item.qty),
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // 1. Tutup Loading
        
        // 2. PERUBAHAN UTAMA: Kirim Data Balik ke PosPage (Bukan buka Invoice di sini)
        Navigator.pop(context, transactionData); 
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Tutup Loading
        showTopSnackBar(Overlay.of(context), CustomSnackBar.error(message: "Gagal: $e"));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Konfirmasi Transaksi"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[50],
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: ElevatedButton(
          onPressed: _processTransaction,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            paymentMethod == "Hutang" ? "SIMPAN TAGIHAN" : "BAYAR ${formatRupiah(grandTotal)}",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // RINGKASAN BELANJA
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: widget.cartItems.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("${item.qty} x ${formatRupiah(item.product.price)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(formatRupiah(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // PELANGGAN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Pelanggan", style: TextStyle(fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: _showAddCustomerDialog,
                  child: const Text("+ Buat Customer", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCustomerId,
                  hint: const Text("Pilih Pelanggan"),
                  isExpanded: true,
                  items: customers.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(c['name']),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedCustomerId = val;
                      selectedCustomerName = customers.firstWhere((c) => c['id'] == val)['name'];
                    });
                  },
                ),
              ),
            ),
            if (paymentMethod == "Hutang" && selectedCustomerId == 'walk-in')
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text("* Hutang wajib pilih pelanggan terdaftar", style: TextStyle(color: Colors.red, fontSize: 11)),
              ),
            
            const SizedBox(height: 20),

            // TANGGAL TRANSAKSI
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Tgl Mulai", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: startDateController,
                      readOnly: true,
                      onTap: () => _pickDate(isStart: true),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        filled: true, fillColor: Colors.white,
                        suffixIcon: const Icon(Icons.calendar_today, size: 16),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Tgl Selesai", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: endDateController,
                      readOnly: true,
                      onTap: () => _pickDate(isStart: false),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "Opsional",
                        filled: true, fillColor: Colors.white,
                        suffixIcon: const Icon(Icons.event_available, size: 16),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ]),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // GRAND TOTAL & DISKON (PIN PROTECTED)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal"), Text(formatRupiah(widget.subtotal))]),
                  
                  // --- DISKON DENGAN PIN ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Diskon", style: TextStyle(color: Colors.red)),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: discountController,
                          readOnly: true, // KUNCI FIELD INI
                          onTap: _showPinDialog, // BUKA PIN DIALOG KALAU DIKLIK
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.red),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: "0",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.redAccent),
                            suffixIcon: Icon(Icons.lock, size: 14, color: Colors.grey), // Ikon Gembok
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Grand Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900)),
                        Text(formatRupiah(grandTotal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // METODE PEMBAYARAN
            const Text("Metode Pembayaran", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPaymentOption("Cash", Icons.money),
                const SizedBox(width: 10),
                _buildPaymentOption("Non-Cash", Icons.qr_code_scanner),
                const SizedBox(width: 10),
                _buildPaymentOption("Hutang", Icons.book),
              ],
            ),

            const SizedBox(height: 20),

            // KOLOM DINAMIS
            if (paymentMethod == "Non-Cash") ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Detail Non-Cash", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedNonCashType,
                      decoration: const InputDecoration(
                        labelText: "Pilih Bank / E-Wallet",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        filled: true, fillColor: Colors.white,
                      ),
                      items: nonCashOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() => selectedNonCashType = newValue);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: refNoController,
                      decoration: const InputDecoration(
                        labelText: "No. Ref / Catatan (Opsional)",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        filled: true, fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (paymentMethod == "Hutang") ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Tanggal Jatuh Tempo (Wajib)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dueDateController,
                      readOnly: true,
                      onTap: () => _pickDate(isStart: false, isDue: true),
                      decoration: InputDecoration(
                        hintText: "Pilih tanggal bayar...",
                        filled: true, fillColor: Colors.white,
                        suffixIcon: const Icon(Icons.calendar_month, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            const Text("Total Bayar / Diterima / DP", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: payAmountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "Masukkan nominal...",
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixText: "Rp ",
              ),
              onChanged: (val) {
                setState(() {
                  payAmount = int.tryParse(val.replaceAll('.', '')) ?? 0;
                });
              },
            ),
            
            if (paymentMethod == "Cash") ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickMoneyButton(grandTotal), 
                    _buildQuickMoneyButton(10000),
                    _buildQuickMoneyButton(20000),
                    _buildQuickMoneyButton(50000),
                    _buildQuickMoneyButton(100000),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),
            
            if (paymentMethod == "Hutang")
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Sisa Tagihan:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  Text(formatRupiah(grandTotal - payAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              )
            else if (payAmount > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Kembalian:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    formatRupiah(change),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: change >= 0 ? Colors.blue : Colors.red),
                  ),
                ],
              ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String title, IconData icon) {
    final bool isSelected = paymentMethod == title;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            paymentMethod = title;
            if (title == "Hutang") {
              payAmount = 0;
              payAmountController.text = "0";
            } else {
              payAmount = grandTotal;
              payAmountController.text = grandTotal.toString();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? Colors.blue : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}