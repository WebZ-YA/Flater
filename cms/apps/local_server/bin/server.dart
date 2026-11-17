import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:cms_core/core.dart';
import '../database/cms_database.dart';
import '../sync/sync_worker.dart';

class LocalSessionContext {
  const LocalSessionContext({
    required this.uid,
    required this.tenantId,
    required this.role,
    required this.deviceId,
  });

  final String uid;
  final String tenantId;
  final ClinicRole role;
  final String deviceId;
}

class LocalClinicServer {
  LocalClinicServer({
    required this.db,
    required this.hmacSecret,
    required this.localStorageRoot,
    this.cloudSyncEndpoint,
  }) : syncWorker = BackgroundSyncWorker(
          db: db,
          cloudSyncEndpoint: cloudSyncEndpoint,
          deviceId: 'local-clinic-server-win',
        );

  final CmsLocalDatabase db;
  final String hmacSecret;
  final Directory localStorageRoot;
  final Uri? cloudSyncEndpoint;
  final BackgroundSyncWorker syncWorker;
  final Set<WebSocketChannel> _lanClients = {};

  void _broadcastLanEvent(String eventType, Map<String, dynamic> payload) {
    final frame = jsonEncode({
      'event': eventType,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': payload,
    });
    for (final client in _lanClients.toList()) {
      try {
        client.sink.add(frame);
      } catch (_) {
        _lanClients.remove(client);
      }
    }
  }

  LocalSessionContext? _verifySessionHeader(Request req) {
    final authHeader = req.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }
    final token = authHeader.substring(7).trim();
    final parts = token.split('.');
    if (parts.length != 2) return null;

    final payloadB64 = parts[0];
    final sigHex = parts[1];
    final expectedSig = Hmac(sha256, utf8.encode(hmacSecret))
        .convert(utf8.encode(payloadB64))
        .toString();

    if (sigHex != expectedSig) return null;
    final payload = jsonDecode(utf8.decode(base64Url.decode(payloadB64))) as Map<String, dynamic>;
    final exp = DateTime.parse(payload['exp'] as String);
    if (DateTime.now().toUtc().isAfter(exp)) return null;

    return LocalSessionContext(
      uid: payload['uid'] as String,
      tenantId: payload['tenantId'] as String,
      role: ClinicRole.fromCode(payload['role'] as String),
      deviceId: (payload['deviceId'] as String?) ?? 'lan-client',
    );
  }

  Handler buildHandler() {
    final router = Router();

    router.get('/health', (Request req) async {
      final pendingOutbox = await (db.select(db.syncOutbox)
            ..where((t) => t.status.equals('synced').not()))
          .get();
      return _jsonOk({
        'status': 'healthy',
        'mode': 'hybrid_local_server',
        'pendingOutboxCount': pendingOutbox.length,
        'lanClientsConnected': _lanClients.length,
      });
    });

    // Real-time LAN WebSocket for Waiting Room Display & Doctor Queue Alerts
    router.get(
      '/ws/lan',
      webSocketHandler((WebSocketChannel channel, String? protocol) {
        _lanClients.add(channel);
        channel.stream.listen(
          (_) {},
          onDone: () => _lanClients.remove(channel),
          onError: (_) => _lanClients.remove(channel),
        );
      }),
    );

    // Patients: Search & Duplicate Check + Creation
    router.get('/api/v1/patients', (Request req) async {
      final session = _verifySessionHeader(req);
      if (session == null) return _jsonError(401, 'UNAUTHORIZED');
      if (!RbacPolicyEngine.hasPermission(
          role: session.role, permission: ClinicPermission.patientsRead)) {
        return _jsonError(403, 'FORBIDDEN');
      }

      final q = (req.url.queryParameters['q'] ?? '').trim().toLowerCase();
      final rows = await (db.select(db.localPatients)
            ..where((t) => t.tenantId.equals(session.tenantId) & t.archived.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(100))
          .get();

      final filtered = q.isEmpty
          ? rows
          : rows.where((p) =>
              p.fullName.toLowerCase().contains(q) ||
              p.phone.contains(q) ||
              p.medicalNumber.toLowerCase().contains(q));

      return _jsonOk({
        'items': filtered
            .map((p) => {
                  'id': p.id,
                  'medicalNumber': p.medicalNumber,
                  'fullName': p.fullName,
                  'gender': p.gender,
                  'phone': p.phone,
                  'bloodType': p.bloodType,
                  'allergies': jsonDecode(p.allergiesJson),
                  'chronicConditions': jsonDecode(p.chronicConditionsJson),
                  'recordVersion': p.recordVersion,
                })
            .toList(),
      });
    });

    router.post('/api/v1/patients', (Request req) async {
      final session = _verifySessionHeader(req);
      if (session == null) return _jsonError(401, 'UNAUTHORIZED');
      if (!RbacPolicyEngine.hasPermission(
          role: session.role, permission: ClinicPermission.patientsWrite)) {
        return _jsonError(403, 'FORBIDDEN');
      }

      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final fullName = (body['fullName'] as String? ?? '').trim();
      final phone = (body['phone'] as String? ?? '').trim();
      if (fullName.length < 2 || phone.isEmpty) {
        return _jsonError(400, 'INVALID_PATIENT_PAYLOAD');
      }

      final normalizedPhone = IdGenerator.normalizePhone(phone);
      final duplicate = await (db.select(db.localPatients)
            ..where((t) =>
                t.tenantId.equals(session.tenantId) & t.normalizedPhone.equals(normalizedPhone)))
          .get();
      if (duplicate.isNotEmpty && body['confirmDuplicateOverride'] != true) {
        return _jsonError(409, 'POTENTIAL_DUPLICATE_PATIENT', extra: {
          'existingMedicalNumber': duplicate.first.medicalNumber,
        });
      }

      final existingCount = await (db.select(db.localPatients)
            ..where((t) => t.tenantId.equals(session.tenantId)))
          .get();
      final medicalNumber = IdGenerator.formatSequentialNumber('PAT', existingCount.length + 1);
      final patientId = IdGenerator.newUuid();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final payload = {
        'id': patientId,
        'tenantId': session.tenantId,
        'medicalNumber': medicalNumber,
        'fullName': fullName,
        'gender': body['gender'] ?? 'male',
        'phone': phone,
        'normalizedPhone': normalizedPhone,
        'address': body['address'] ?? '',
        'bloodType': body['bloodType'],
        'allergies': body['allergies'] ?? [],
        'chronicConditions': body['chronicConditions'] ?? [],
        'archived': false,
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'createdBy': session.uid,
        'updatedBy': session.uid,
        'schemaVersion': 1,
        'recordVersion': 1,
      };

      await db.runAuditedOutboxTransaction(
        tenantId: session.tenantId,
        actorId: session.uid,
        actorRole: session.role.code,
        action: 'PATIENT_CREATED',
        entityType: 'patients',
        entityId: patientId,
        operation: 'create',
        baseVersion: 1,
        payload: payload,
        sourceDevice: session.deviceId,
        writeDomainTable: () async {
          await db.into(db.localPatients).insert(
                LocalPatientsCompanion.insert(
                  id: patientId,
                  tenantId: session.tenantId,
                  clinicId: session.tenantId,
                  branchId: 'main-branch',
                  medicalNumber: medicalNumber,
                  fullName: fullName,
                  gender: (body['gender'] as String?) ?? 'male',
                  phone: phone,
                  normalizedPhone: normalizedPhone,
                  address: Value((body['address'] as String?) ?? ''),
                  bloodType: Value(body['bloodType'] as String?),
                  allergiesJson: Value(jsonEncode(body['allergies'] ?? [])),
                  chronicConditionsJson: Value(jsonEncode(body['chronicConditions'] ?? [])),
                  createdAt: nowIso,
                  updatedAt: nowIso,
                  createdBy: session.uid,
                  updatedBy: session.uid,
                ),
              );
        },
        afterSummary: {'medicalNumber': medicalNumber},
      );

      PhiSafeLogger.info('LocalServer', 'Patient registered', {'patientId': patientId});
      return _jsonOk(payload, statusCode: 201);
    });

    // Queue Management + Real-time WebSocket LAN Broadcast
    router.post('/api/v1/queue/tickets', (Request req) async {
      final session = _verifySessionHeader(req);
      if (session == null) return _jsonError(401, 'UNAUTHORIZED');
      if (!RbacPolicyEngine.hasPermission(
          role: session.role, permission: ClinicPermission.queueManage)) {
        return _jsonError(403, 'FORBIDDEN');
      }

      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final todaysTickets = await (db.select(db.localQueueTickets)
            ..where((t) => t.tenantId.equals(session.tenantId) & t.queueDate.equals(today)))
          .get();

      final ticketNumber = todaysTickets.length + 1;
      final ticketId = IdGenerator.newUuid();
      final nowIso = DateTime.now().toUtc().toIso8601String();

      final payload = {
        'id': ticketId,
        'tenantId': session.tenantId,
        'branchId': 'main-branch',
        'queueDate': today,
        'ticketNumber': ticketNumber,
        'patientId': body['patientId'],
        'patientName': body['patientName'],
        'doctorId': body['doctorId'],
        'visitType': body['visitType'] ?? 'first_consultation',
        'status': 'waiting',
        'createdAt': nowIso,
        'updatedAt': nowIso,
        'createdBy': session.uid,
        'updatedBy': session.uid,
        'recordVersion': 1,
      };

      await db.runAuditedOutboxTransaction(
        tenantId: session.tenantId,
        actorId: session.uid,
        actorRole: session.role.code,
        action: 'QUEUE_TICKET_ISSUED',
        entityType: 'queue_tickets',
        entityId: ticketId,
        operation: 'create',
        baseVersion: 1,
        payload: payload,
        sourceDevice: session.deviceId,
        writeDomainTable: () async {
          await db.into(db.localQueueTickets).insert(
                LocalQueueTicketsCompanion.insert(
                  id: ticketId,
                  tenantId: session.tenantId,
                  branchId: 'main-branch',
                  queueDate: today,
                  ticketNumber: ticketNumber,
                  patientId: body['patientId'] as String,
                  patientName: body['patientName'] as String,
                  doctorId: body['doctorId'] as String,
                  visitType: (body['visitType'] as String?) ?? 'first_consultation',
                  status: 'waiting',
                  createdAt: nowIso,
                  updatedAt: nowIso,
                  createdBy: session.uid,
                  updatedBy: session.uid,
                ),
              );
        },
      );

      _broadcastLanEvent('queue.updated', payload);
      return _jsonOk(payload, statusCode: 201);
    });

    router.post('/api/v1/sync/trigger', (Request req) async {
      final session = _verifySessionHeader(req);
      if (session == null) return _jsonError(401, 'UNAUTHORIZED');
      final report = await syncWorker.runSyncCycle();
      return _jsonOk({
        'pushedCount': report.pushedCount,
        'conflictsDetected': report.conflictsDetected,
        'failedCount': report.failedCount,
        'ranAt': report.ranAt.toIso8601String(),
      });
    });

    return router.call;
  }

  Future<HttpServer> start({InternetAddress? address, int port = 8085}) async {
    if (!localStorageRoot.existsSync()) {
      localStorageRoot.createSync(recursive: true);
    }
    syncWorker.start();
    final pipeline = const Pipeline().addMiddleware(logRequests()).addHandler(buildHandler());
    return shelf_io.serve(pipeline, address ?? InternetAddress.anyIPv4, port);
  }

  Response _jsonOk(Map<String, dynamic> body, {int statusCode = 200}) {
    return Response(
      statusCode,
      body: jsonEncode(body),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }

  Response _jsonError(int statusCode, String code, {Map<String, dynamic>? extra}) {
    return Response(
      statusCode,
      body: jsonEncode({'error': code, ...?extra}),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    );
  }
}

Future<void> main(List<String> args) async {
  final dbPath = Platform.environment['CMS_LOCAL_DB_PATH'] ?? 'cms_clinic_local.db';
  final hmacSecret = Platform.environment['CMS_LOCAL_HMAC_SECRET'] ?? 'dev-local-only-secret-change-in-prod';
  final storageDir = Directory(Platform.environment['CMS_LOCAL_STORAGE_DIR'] ?? './local_vault');
  final cloudUrl = Platform.environment['CMS_CLOUD_SYNC_URL'];

  final db = CmsLocalDatabase.openFile(dbPath);
  final server = LocalClinicServer(
    db: db,
    hmacSecret: hmacSecret,
    localStorageRoot: storageDir,
    cloudSyncEndpoint: cloudUrl != null ? Uri.parse(cloudUrl) : null,
  );

  final httpServer = await server.start(port: 8085);
  PhiSafeLogger.info(
    'LocalClinicServer',
    'Listening on LAN port ${httpServer.port}',
    {'port': httpServer.port},
  );
}
