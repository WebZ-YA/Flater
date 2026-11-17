import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:cms_core/core.dart';

part 'cms_database.g.dart';

// -----------------------------------------------------------------------------
// SRS §10 Required 15 Local Tables + Supporting Clinical/Financial/Audit Tables
// -----------------------------------------------------------------------------

class LocalPatients extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get clinicId => text()();
  TextColumn get branchId => text()();
  TextColumn get medicalNumber => text()();
  TextColumn get fullName => text()();
  TextColumn get gender => text()();
  TextColumn get phone => text()();
  TextColumn get normalizedPhone => text()();
  TextColumn get dateOfBirth => text().nullable()();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get bloodType => text().nullable()();
  TextColumn get allergiesJson => text().withDefault(const Constant('[]'))();
  TextColumn get chronicConditionsJson => text().withDefault(const Constant('[]'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();
  TextColumn get deletedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalAppointments extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text()();
  TextColumn get startAt => text()();
  TextColumn get endAt => text()();
  TextColumn get visitType => text()();
  TextColumn get status => text()(); // scheduled | confirmed | checked_in | cancelled | no_show | completed
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalQueueTickets extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get queueDate => text()();
  IntColumn get ticketNumber => integer()();
  TextColumn get patientId => text()();
  TextColumn get patientName => text()();
  TextColumn get doctorId => text()();
  TextColumn get appointmentId => text().nullable()();
  TextColumn get visitType => text()();
  TextColumn get status => text()(); // waiting | called | in_consultation | skipped | completed | cancelled
  IntColumn get skipCount => integer().withDefault(const Constant(0))();
  TextColumn get calledAt => text().nullable()();
  TextColumn get completedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalVisits extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get visitNumber => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text()();
  TextColumn get appointmentId => text().nullable()();
  TextColumn get queueTicketId => text().nullable()();
  TextColumn get visitType => text()();
  TextColumn get visitReason => text()();
  TextColumn get status => text()(); // in_progress | finalized | cancelled
  TextColumn get finalizedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalConsultations extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get visitId => text()();
  TextColumn get patientId => text()();
  TextColumn get doctorId => text()();
  TextColumn get chiefComplaint => text().withDefault(const Constant(''))();
  TextColumn get symptoms => text().withDefault(const Constant(''))();
  TextColumn get medicalHistory => text().withDefault(const Constant(''))();
  TextColumn get vitalsJson => text().withDefault(const Constant('{}'))();
  TextColumn get physicalExam => text().withDefault(const Constant(''))();
  TextColumn get diagnosesJson => text().withDefault(const Constant('[]'))();
  TextColumn get clinicalNotes => text().withDefault(const Constant(''))();
  TextColumn get treatmentPlan => text().withDefault(const Constant(''))();
  BoolColumn get isDraft => boolean().withDefault(const Constant(true))();
  TextColumn get approvedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalLabOrders extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get orderNumber => text()();
  TextColumn get patientId => text()();
  TextColumn get visitId => text()();
  TextColumn get doctorId => text()();
  TextColumn get laboratoryId => text()();
  TextColumn get testIdsJson => text()();
  TextColumn get status => text()(); // issued | sent | partial_results | completed | cancelled
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalLabResults extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get orderId => text()();
  TextColumn get patientId => text()();
  TextColumn get visitId => text()();
  TextColumn get laboratoryId => text()();
  TextColumn get source => text()(); // manual | portal | api
  TextColumn get localFilePath => text().nullable()();
  TextColumn get structuredValuesJson => text().withDefault(const Constant('[]'))();
  TextColumn get reviewStatus => text()(); // pending_review | approved | rejected
  TextColumn get reviewedBy => text().nullable()();
  TextColumn get reviewedAt => text().nullable()();
  TextColumn get doctorNotes => text().withDefault(const Constant(''))();
  TextColumn get receivedAt => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPrescriptions extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get rxNumber => text()();
  TextColumn get patientId => text()();
  TextColumn get visitId => text()();
  TextColumn get doctorId => text()();
  TextColumn get itemsJson => text()();
  TextColumn get status => text()(); // active | modified | cancelled
  TextColumn get revisionOf => text().nullable()();
  TextColumn get cancelReason => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get patientId => text()();
  TextColumn get visitId => text().nullable()();
  TextColumn get itemsJson => text()();
  RealColumn get clinicServicesSubtotal => real()();
  RealColumn get externalLabPassThrough => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalDue => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('YER'))();
  TextColumn get status => text()(); // draft | issued | partially_paid | paid | void
  TextColumn get discountAuthorizedBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPayments extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get invoiceId => text()();
  TextColumn get patientId => text()();
  TextColumn get shiftId => text()();
  TextColumn get paymentReference => text()(); // Unique to prevent duplicate billing
  TextColumn get receiptNumber => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('YER'))();
  TextColumn get method => text()(); // cash | card | transfer
  TextColumn get type => text()(); // payment | refund
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get patientId => text()();
  TextColumn get visitId => text().nullable()();
  TextColumn get labOrderId => text().nullable()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  TextColumn get localPath => text()();
  TextColumn get remoteStoragePath => text().nullable()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get shiftId => text().nullable()();
  TextColumn get category => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('YER'))();
  TextColumn get vendor => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();
  TextColumn get createdBy => text()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalCashboxShifts extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get branchId => text()();
  TextColumn get cashierId => text()();
  TextColumn get openedAt => text()();
  TextColumn get closedAt => text().nullable()();
  RealColumn get openingBalance => real()();
  RealColumn get totalCashIn => real().withDefault(const Constant(0.0))();
  RealColumn get totalCashOut => real().withDefault(const Constant(0.0))();
  RealColumn get actualCountedBalance => real().nullable()();
  TextColumn get status => text()(); // open | closed
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_push'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalAuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get actorId => text()();
  TextColumn get actorRole => text()();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get sourceDevice => text()();
  TextColumn get occurredAt => text()();
  TextColumn get beforeSummaryJson => text().nullable()();
  TextColumn get afterSummaryJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // create | update | delete
  TextColumn get idempotencyKey => text()();
  IntColumn get baseVersion => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get nextRetryAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncInbox extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get operationId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get remoteVersion => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get appliedAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  IntColumn get localVersion => integer()();
  IntColumn get remoteVersion => integer()();
  TextColumn get localJson => text()();
  TextColumn get remoteJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending_review'))();
  TextColumn get resolutionNote => text().nullable()();
  TextColumn get resolvedBy => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get resolvedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  LocalPatients,
  LocalAppointments,
  LocalQueueTickets,
  LocalVisits,
  LocalConsultations,
  LocalLabOrders,
  LocalLabResults,
  LocalPrescriptions,
  LocalInvoices,
  LocalPayments,
  LocalDocuments,
  LocalExpenses,
  LocalCashboxShifts,
  LocalAuditLogs,
  SyncOutbox,
  SyncInbox,
  SyncConflicts,
  SyncMetadata,
])
class CmsLocalDatabase extends _$CmsLocalDatabase {
  CmsLocalDatabase(super.e);

  factory CmsLocalDatabase.openFile(String path) {
    return CmsLocalDatabase(NativeDatabase(File(path)));
  }

  factory CmsLocalDatabase.inMemory() {
    return CmsLocalDatabase(NativeDatabase.memory());
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_patients_medical_no ON local_patients(tenant_id, medical_number);',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_payments_ref ON local_payments(tenant_id, payment_reference);',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_outbox_idemp ON sync_outbox(idempotency_key);',
          );
        },
      );

  /// Atomic helper: commits any local mutation alongside its Outbox entry & Audit Log
  Future<void> runAuditedOutboxTransaction({
    required String tenantId,
    required String actorId,
    required String actorRole,
    required String action,
    required String entityType,
    required String entityId,
    required String operation,
    required int baseVersion,
    required Map<String, dynamic> payload,
    required String sourceDevice,
    required Future<void> Function() writeDomainTable,
    Map<String, dynamic>? beforeSummary,
    Map<String, dynamic>? afterSummary,
  }) {
    return transaction(() async {
      await writeDomainTable();

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final outboxId = IdGenerator.newUuid();
      await into(syncOutbox).insert(
        SyncOutboxCompanion.insert(
          id: outboxId,
          tenantId: tenantId,
          entityType: entityType,
          entityId: entityId,
          operation: operation,
          idempotencyKey: '$entityType:$entityId:$baseVersion:$outboxId',
          baseVersion: baseVersion,
          payloadJson: jsonEncode(payload),
          createdAt: nowIso,
        ),
      );

      await into(localAuditLogs).insert(
        LocalAuditLogsCompanion.insert(
          id: IdGenerator.newUuid(),
          tenantId: tenantId,
          actorId: actorId,
          actorRole: actorRole,
          action: action,
          entityType: entityType,
          entityId: entityId,
          sourceDevice: sourceDevice,
          occurredAt: nowIso,
          beforeSummaryJson: Value(beforeSummary == null ? null : jsonEncode(beforeSummary)),
          afterSummaryJson: Value(afterSummary == null ? null : jsonEncode(afterSummary)),
        ),
      );
    });
  }
}
