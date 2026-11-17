import 'package:test/test.dart';
import 'package:cms_core/core.dart';

void main() {
  group('RBAC Policy Engine', () {
    test('Receptionist cannot finalize consultation or approve lab results', () {
      expect(
        RbacPolicyEngine.hasPermission(
          role: ClinicRole.receptionist,
          permission: ClinicPermission.consultationFinalize,
        ),
        isFalse,
      );
      expect(
        RbacPolicyEngine.hasPermission(
          role: ClinicRole.receptionist,
          permission: ClinicPermission.labResultsApprove,
        ),
        isFalse,
      );
    });

    test('Doctor can finalize consultation and approve lab results', () {
      expect(
        RbacPolicyEngine.hasPermission(
          role: ClinicRole.doctor,
          permission: ClinicPermission.consultationFinalize,
        ),
        isTrue,
      );
      expect(
        RbacPolicyEngine.hasPermission(
          role: ClinicRole.doctor,
          permission: ClinicPermission.labResultsApprove,
        ),
        isTrue,
      );
    });
  });

  group('PHI Safe Logger', () {
    test('Redacts sensitive patient and clinical keys', () {
      final sanitized = PhiSafeLogger.sanitizeMetadata({
        'patientId': 'uuid-123',
        'fullName': 'محمد علي',
        'diagnoses': ['Type 2 Diabetes'],
        'phone': '777000111',
      });
      expect(sanitized['patientId'], 'uuid-123');
      expect(sanitized['fullName'], '[REDACTED_PHI]');
      expect(sanitized['diagnoses'], '[REDACTED_PHI]');
      expect(sanitized['phone'], '[REDACTED_PHI]');
    });
  });
}
