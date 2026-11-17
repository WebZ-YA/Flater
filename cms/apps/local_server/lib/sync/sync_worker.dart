import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:cms_core/core.dart';
import '../database/cms_database.dart';

class SyncCycleReport {
  const SyncCycleReport({
    required this.pushedCount,
    required this.conflictsDetected,
    required this.failedCount,
    required this.ranAt,
  });

  final int pushedCount;
  final int conflictsDetected;
  final int failedCount;
  final DateTime ranAt;
}

class BackgroundSyncWorker {
  BackgroundSyncWorker({
    required this.db,
    required this.cloudSyncEndpoint,
    required this.deviceId,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final CmsLocalDatabase db;
  final Uri? cloudSyncEndpoint;
  final String deviceId;
  final http.Client _http;
  Timer? _timer;
  bool _isRunning = false;

  void start({Duration interval = const Duration(seconds: 20)}) {
    _recoverStuckInFlightOperations();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => runSyncCycle());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// SRS §11: Recover operations left in_flight after power loss or app crash
  Future<void> _recoverStuckInFlightOperations() async {
    await (db.update(db.syncOutbox)..where((t) => t.status.equals('in_flight'))).write(
      const SyncOutboxCompanion(status: Value('pending')),
    );
  }

  Future<SyncCycleReport> runSyncCycle({String? authBearerToken}) async {
    if (_isRunning || cloudSyncEndpoint == null) {
      return SyncCycleReport(
        pushedCount: 0,
        conflictsDetected: 0,
        failedCount: 0,
        ranAt: DateTime.now().toUtc(),
      );
    }

    _isRunning = true;
    var pushed = 0;
    var conflicts = 0;
    var failed = 0;

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final pending = await (db.select(db.syncOutbox)
            ..where(
              (t) =>
                  t.status.equals('pending') |
                  (t.status.equals('failed') & t.nextRetryAt.isSmallerOrEqualValue(nowIso)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(25))
          .get();

      if (pending.isEmpty) {
        return SyncCycleReport(
          pushedCount: 0,
          conflictsDetected: 0,
          failedCount: 0,
          ranAt: DateTime.now().toUtc(),
        );
      }

      // Mark in_flight
      for (final op in pending) {
        await (db.update(db.syncOutbox)..where((t) => t.id.equals(op.id))).write(
          const SyncOutboxCompanion(status: Value('in_flight')),
        );
      }

      final response = await _http
          .post(
            cloudSyncEndpoint!,
            headers: {
              'Content-Type': 'application/json',
              if (authBearerToken != null) 'Authorization': 'Bearer $authBearerToken',
            },
            body: jsonEncode({
              'tenantId': pending.first.tenantId,
              'operations': pending
                  .map((op) => {
                        'operationId': op.id,
                        'idempotencyKey': op.idempotencyKey,
                        'tenantId': op.tenantId,
                        'entityType': op.entityType,
                        'entityId': op.entityId,
                        'operation': op.operation,
                        'baseVersion': op.baseVersion,
                        'payload': jsonDecode(op.payloadJson),
                        'deviceId': deviceId,
                        'occurredAt': op.createdAt,
                      })
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (decoded['results'] as List<dynamic>? ?? []);
        for (final item in results) {
          final map = item as Map<String, dynamic>;
          final opId = map['operationId'] as String;
          final status = map['status'] as String;
          final op = pending.firstWhere((e) => e.id == opId);

          if (status == 'applied' || status == 'already_processed') {
            await (db.update(db.syncOutbox)..where((t) => t.id.equals(opId))).write(
              const SyncOutboxCompanion(status: Value('synced')),
            );
            pushed++;
          } else if (status == 'conflict') {
            await (db.update(db.syncOutbox)..where((t) => t.id.equals(opId))).write(
              const SyncOutboxCompanion(status: Value('conflict')),
            );
            await db.into(db.syncConflicts).insertOnConflictUpdate(
                  SyncConflictsCompanion.insert(
                    id: (map['conflictId'] as String?) ?? IdGenerator.newUuid(),
                    tenantId: op.tenantId,
                    entityType: op.entityType,
                    entityId: op.entityId,
                    localVersion: op.baseVersion,
                    remoteVersion: (map['remoteVersion'] as int?) ?? op.baseVersion + 1,
                    localJson: op.payloadJson,
                    remoteJson: jsonEncode(map['remoteSnapshot'] ?? {}),
                    createdAt: DateTime.now().toUtc().toIso8601String(),
                  ),
                );
            conflicts++;
          } else {
            await _scheduleRetry(op, map['reason']?.toString() ?? 'REJECTED');
            failed++;
          }
        }
      } else {
        for (final op in pending) {
          await _scheduleRetry(op, 'HTTP_${response.statusCode}');
          failed++;
        }
      }
    } catch (err) {
      PhiSafeLogger.error('SyncWorker', 'SYNC_CYCLE_ERROR', err);
    } finally {
      _isRunning = false;
    }

    return SyncCycleReport(
      pushedCount: pushed,
      conflictsDetected: conflicts,
      failedCount: failed,
      ranAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _scheduleRetry(SyncOutboxData op, String errorCode) async {
    final nextRetryCount = op.retryCount + 1;
    final delaySeconds = switch (nextRetryCount) {
      1 => 5,
      2 => 15,
      3 => 30,
      4 => 60,
      _ => 120,
    };
    final nextRetryAt =
        DateTime.now().toUtc().add(Duration(seconds: delaySeconds)).toIso8601String();
    await (db.update(db.syncOutbox)..where((t) => t.id.equals(op.id))).write(
      SyncOutboxCompanion(
        status: const Value('failed'),
        retryCount: Value(nextRetryCount),
        lastError: Value(errorCode),
        nextRetryAt: Value(nextRetryAt),
      ),
    );
  }
}
