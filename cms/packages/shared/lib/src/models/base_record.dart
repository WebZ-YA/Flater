abstract class BaseCmsRecord {
  const BaseCmsRecord({
    required this.id,
    required this.tenantId,
    required this.clinicId,
    required this.branchId,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
    this.schemaVersion = 1,
    this.recordVersion = 1,
    this.syncStatus = 'pending_push',
    this.deletedAt,
  });

  final String id;
  final String tenantId;
  final String clinicId;
  final String branchId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;
  final int schemaVersion;
  final int recordVersion;
  final String syncStatus;
  final DateTime? deletedAt;
}
