import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String currencyCode = 'YER'}) {
    final formatter = NumberFormat('#,##0.##', 'ar');
    final symbol = switch (currencyCode) {
      'YER' => 'ر.ي',
      'SAR' => 'ر.س',
      'USD' => '\$',
      _ => currencyCode,
    };
    return '${formatter.format(amount)} $symbol';
  }
}
