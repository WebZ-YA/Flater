import 'package:uuid/uuid.dart';

class IdGenerator {
  static const Uuid _uuid = Uuid();

  static String newUuid() => _uuid.v4();

  static String formatSequentialNumber(String prefix, int sequence) {
    final padded = sequence.toString().padLeft(6, '0');
    return '$prefix-$padded';
  }

  static String normalizePhone(String rawPhone) {
    final digitsOnly = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digitsOnly.startsWith('00')) {
      return '+${digitsOnly.substring(2)}';
    }
    return digitsOnly;
  }
}
