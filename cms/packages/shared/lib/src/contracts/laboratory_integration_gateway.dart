/// SRS §10: General Laboratory Integration Interface supporting:
/// 1. Manual PDF/Image Entry
/// 2. External Laboratory Portal
/// 3. Documented Lab API / Webhook Integration (only when contractually verified)
enum LabIntegrationMode { manual, portal, api }

class LabDispatchReceipt {
  const LabDispatchReceipt({
    required this.accepted,
    required this.externalReference,
    required this.mode,
    this.message,
  });

  final bool accepted;
  final String externalReference;
  final LabIntegrationMode mode;
  final String? message;
}

class LabStructuredTestValue {
  const LabStructuredTestValue({
    required this.testCode,
    required this.parameterName,
    required this.value,
    required this.unit,
    required this.referenceRange,
    this.isAbnormal = false,
  });

  final String testCode;
  final String parameterName;
  final String value;
  final String unit;
  final String referenceRange;
  final bool isAbnormal;
}

abstract interface class LaboratoryIntegrationGateway {
  LabIntegrationMode get mode;
  String get providerId;

  Future<LabDispatchReceipt> submitLabOrder({
    required String tenantId,
    required String orderId,
    required String orderNumber,
    required String patientMedicalNumber,
    required List<String> testCodes,
  });

  Future<bool> verifyHealth();
}

/// Default manual gateway used when an external lab does not have a documented API.
class ManualLaboratoryGateway implements LaboratoryIntegrationGateway {
  const ManualLaboratoryGateway(this.providerId);

  @override
  final String providerId;

  @override
  LabIntegrationMode get mode => LabIntegrationMode.manual;

  @override
  Future<LabDispatchReceipt> submitLabOrder({
    required String tenantId,
    required String orderId,
    required String orderNumber,
    required String patientMedicalNumber,
    required List<String> testCodes,
  }) async {
    return LabDispatchReceipt(
      accepted: true,
      externalReference: orderNumber,
      mode: LabIntegrationMode.manual,
      message: 'تم تجهيز نموذج الطلب للطباعة والتسليم اليدوي للمختبر.',
    );
  }

  @override
  Future<bool> verifyHealth() async => true;
}
