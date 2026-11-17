enum SyncOperationKind { create, update, delete }

enum OutboxStatus { pending, inFlight, synced, conflict, failed }

class SyncOutboxOperation {
  const SyncOutboxOperation({
    required this.id,
    required this.tenantId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.idempotencyKey,
    required this.baseVersion,
    required this.payloadJson,
    required this.status,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    this.nextRetryAt,
  });

  final String id;
  final String tenantId;
  final String entityType;
  final String entityId;
  final SyncOperationKind operation;
  final String idempotencyKey;
  final int baseVersion;
  final String payloadJson;
  final OutboxStatus status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? nextRetryAt;
}

class SyncConflictRecord {
  const SyncConflictRecord({
    required this.id,
    required this.tenantId,
    required this.entityType,
    required this.entityId,
    required this.localVersion,
    required this.remoteVersion,
    required this.localJson,
    required this.remoteJson,
    required this.status,
    required this.createdAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNote,
  });

  final String id;
  final String tenantId;
  final String entityType;
  final String entityId;
  final int localVersion;
  final int remoteVersion;
  final String localJson;
  final String remoteJson;
  final String status; // pending_review | resolved_local | resolved_remote | merged
  final DateTime createdAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNote;
}
