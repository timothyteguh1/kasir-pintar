import 'package:intl/intl.dart';

String formatCurrency(num number) {
  final format = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  return format.format(number);
}

// Contoh output: Rp 150.000