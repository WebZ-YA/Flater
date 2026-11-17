import 'base_record.dart';

class PatientRecord extends BaseCmsRecord {
  const PatientRecord({
    required super.id,
    required super.tenantId,
    required super.clinicId,
    required super.branchId,
    required super.createdAt,
    required super.updatedAt,
    required super.createdBy,
    required super.updatedBy,
    super.schemaVersion,
    super.recordVersion,
    super.syncStatus,
    super.deletedAt,
    required this.medicalNumber,
    required this.fullName,
    required this.gender,
    required this.phone,
    required this.normalizedPhone,
    this.dateOfBirth,
    this.address = '',
    this.bloodType,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.archived = false,
  });

  final String medicalNumber;
  final String fullName;
  final String gender;
  final String phone;
  final String normalizedPhone;
  final DateTime? dateOfBirth;
  final String address;
  final String? bloodType;
  final List<String> allergies;
  final List<String> chronicConditions;
  final bool archived;

  /// SRS §8.1: QR payload contains ONLY non-sensitive medical number + tenant/patient ID
  String get nonSensitiveQrPayload => 'CMS-PAT:$tenantId:$medicalNumber';

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'clinicId': clinicId,
        'branchId': branchId,
        'medicalNumber': medicalNumber,
        'fullName': fullName,
        'gender': gender,
        'phone': phone,
        'normalizedPhone': normalizedPhone,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'address': address,
        'bloodType': bloodType,
        'allergies': allergies,
        'chronicConditions': chronicConditions,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'schemaVersion': schemaVersion,
        'recordVersion': recordVersion,
        'syncStatus': syncStatus,
      };
}

class QueueTicketRecord extends BaseCmsRecord {
  const QueueTicketRecord({
    required super.id,
    required super.tenantId,
    required super.clinicId,
    required super.branchId,
    required super.createdAt,
    required super.updatedAt,
    required super.createdBy,
    required super.updatedBy,
    super.schemaVersion,
    super.recordVersion,
    super.syncStatus,
    required this.queueDate,
    required this.ticketNumber,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    required this.visitType,
    required this.status,
    this.appointmentId,
    this.calledAt,
    this.completedAt,
    this.skipCount = 0,
  });

  final String queueDate; // YYYY-MM-DD
  final int ticketNumber;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String visitType; // first_consultation | follow_up | urgent
  final String status; // waiting | called | in_consultation | skipped | completed | cancelled
  final String? appointmentId;
  final DateTime? calledAt;
  final DateTime? completedAt;
  final int skipCount;

  String get formattedTicket => 'Q-${ticketNumber.toString().padLeft(3, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'clinicId': clinicId,
        'branchId': branchId,
        'queueDate': queueDate,
        'ticketNumber': ticketNumber,
        'formattedTicket': formattedTicket,
        'patientId': patientId,
        'patientName': patientName,
        'doctorId': doctorId,
        'visitType': visitType,
        'status': status,
        'appointmentId': appointmentId,
        'calledAt': calledAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'skipCount': skipCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'schemaVersion': schemaVersion,
        'recordVersion': recordVersion,
      };
}

class VisitRecord extends BaseCmsRecord {
  const VisitRecord({
    required super.id,
    required super.tenantId,
    required super.clinicId,
    required super.branchId,
    required super.createdAt,
    required super.updatedAt,
    required super.createdBy,
    required super.updatedBy,
    super.schemaVersion,
    super.recordVersion,
    super.syncStatus,
    required this.visitNumber,
    required this.patientId,
    required this.doctorId,
    required this.visitType,
    required this.status,
    required this.visitReason,
    this.appointmentId,
    this.queueTicketId,
    this.finalizedAt,
  });

  final String visitNumber;
  final String patientId;
  final String doctorId;
  final String visitType;
  final String status; // in_progress | finalized | cancelled
  final String visitReason;
  final String? appointmentId;
  final String? queueTicketId;
  final DateTime? finalizedAt;
}

class ConsultationVitals {
  const ConsultationVitals({
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.heartRateBpm,
    this.temperatureCelsius,
    this.respiratoryRate,
    this.spo2Percent,
    this.weightKg,
    this.heightCm,
  });

  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final int? heartRateBpm;
  final double? temperatureCelsius;
  final int? respiratoryRate;
  final int? spo2Percent;
  final double? weightKg;
  final double? heightCm;

  Map<String, dynamic> toJson() => {
        'bloodPressureSystolic': bloodPressureSystolic,
        'bloodPressureDiastolic': bloodPressureDiastolic,
        'heartRateBpm': heartRateBpm,
        'temperatureCelsius': temperatureCelsius,
        'respiratoryRate': respiratoryRate,
        'spo2Percent': spo2Percent,
        'weightKg': weightKg,
        'heightCm': heightCm,
      };
}

class LabOrderRecord extends BaseCmsRecord {
  const LabOrderRecord({
    required super.id,
    required super.tenantId,
    required super.clinicId,
    required super.branchId,
    required super.createdAt,
    required super.updatedAt,
    required super.createdBy,
    required super.updatedBy,
    super.schemaVersion,
    super.recordVersion,
    super.syncStatus,
    required this.orderNumber,
    required this.patientId,
    required this.visitId,
    required this.doctorId,
    required this.laboratoryId,
    required this.testIds,
    required this.status,
  });

  final String orderNumber;
  final String patientId;
  final String visitId;
  final String doctorId;
  final String laboratoryId;
  final List<String> testIds;
  final String status; // issued | sent | partial_results | completed | cancelled

  String get nonSensitiveQrPayload => 'CMS-LAB:$tenantId:$orderNumber';
}

class PrescriptionMedicationItem {
  const PrescriptionMedicationItem({
    required this.tradeName,
    required this.scientificName,
    required this.concentration,
    required this.dosageForm,
    required this.dose,
    required this.frequency,
    required this.duration,
    required this.instructions,
    this.warnings = '',
  });

  final String tradeName;
  final String scientificName;
  final String concentration;
  final String dosageForm;
  final String dose;
  final String frequency;
  final String duration;
  final String instructions;
  final String warnings;

  Map<String, dynamic> toJson() => {
        'tradeName': tradeName,
        'scientificName': scientificName,
        'concentration': concentration,
        'dosageForm': dosageForm,
        'dose': dose,
        'frequency': frequency,
        'duration': duration,
        'instructions': instructions,
        'warnings': warnings,
      };
}
