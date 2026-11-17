/// SRS §5.2 & §9: Never log or send patient names, diagnoses, lab results, or phone numbers
/// to technical logs, Crashlytics, or Analytics.
class PhiSafeLogger {
  static const Set<String> _sensitiveKeys = {
    'fullName',
    'full_name',
    'phone',
    'normalizedPhone',
    'address',
    'chiefComplaint',
    'symptoms',
    'diagnoses',
    'clinicalNotes',
    'treatmentPlan',
    'allergies',
    'chronicConditions',
    'password',
    'token',
  };

  static Map<String, Object?> sanitizeMetadata(Map<String, Object?> input) {
    final sanitized = <String, Object?>{};
    for (final entry in input.entries) {
      if (_sensitiveKeys.contains(entry.key)) {
        sanitized[entry.key] = '[REDACTED_PHI]';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  static void info(String component, String message, [Map<String, Object?>? meta]) {
    final safeMeta = meta == null ? '' : ' ${sanitizeMetadata(meta)}';
    // ignore: avoid_print
    print('[INFO][$component] $message$safeMeta');
  }

  static void error(String component, String code, Object err, [Map<String, Object?>? meta]) {
    final safeMeta = meta == null ? '' : ' ${sanitizeMetadata(meta)}';
    // ignore: avoid_print
    print('[ERROR][$component][$code] ${err.runtimeType}$safeMeta');
  }
}
