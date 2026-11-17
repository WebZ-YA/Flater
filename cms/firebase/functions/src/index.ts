import * as admin from 'firebase-admin';
import * as crypto from 'node:crypto';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { evaluateSyncOperation, SyncEnvelope } from './sync_engine';

admin.initializeApp();
const db = admin.firestore();

const ALLOWED_ROLES = new Set([
  'super_admin',
  'clinic_owner',
  'clinic_manager',
  'receptionist',
  'doctor',
  'nurse',
  'accountant',
  'lab_coordinator',
  'staff',
]);

async function assertActiveMember(tenantId: string, uid: string, requiredRoles?: string[]) {
  const memberSnap = await db
    .collection('tenants')
    .doc(tenantId)
    .collection('memberships')
    .doc(uid)
    .get();

  if (!memberSnap.exists || memberSnap.data()?.active !== true) {
    throw new HttpsError('permission-denied', 'User is not an active member of this clinic.');
  }

  const role = String(memberSnap.data()?.role ?? '');
  if (requiredRoles && !requiredRoles.includes(role)) {
    throw new HttpsError('permission-denied', 'Insufficient role permissions for this operation.');
  }

  return { role, permissions: (memberSnap.data()?.customPermissions as string[]) ?? [] };
}

async function writeAuditLog(params: {
  tenantId: string;
  actorId: string;
  actorRole: string;
  action: string;
  entityType: string;
  entityId: string;
  sourceDevice: string;
  beforeSummary?: Record<string, unknown> | null;
  afterSummary?: Record<string, unknown> | null;
}) {
  const logId = crypto.randomUUID();
  await db
    .collection('tenants')
    .doc(params.tenantId)
    .collection('audit_logs')
    .doc(logId)
    .set({
      id: logId,
      tenantId: params.tenantId,
      actorId: params.actorId,
      actorRole: params.actorRole,
      action: params.action,
      entityType: params.entityType,
      entityId: params.entityId,
      sourceDevice: params.sourceDevice,
      occurredAt: admin.firestore.FieldValue.serverTimestamp(),
      beforeSummary: params.beforeSummary ?? null,
      afterSummary: params.afterSummary ?? null,
    });
}

/**
 * 1. Idempotent Hybrid Sync Ingest Endpoint (Outbox -> Cloud Firestore)
 */
export const syncIngest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const operations = (request.data?.operations ?? []) as SyncEnvelope[];
  const tenantId = String(request.data?.tenantId ?? '');

  if (!tenantId || !Array.isArray(operations) || operations.length === 0) {
    throw new HttpsError('invalid-argument', 'tenantId and non-empty operations array required.');
  }

  const membership = await assertActiveMember(tenantId, request.auth.uid);
  const results: Array<Record<string, unknown>> = [];

  for (const op of operations) {
    if (op.tenantId !== tenantId) {
      results.push({ operationId: op.operationId, status: 'rejected', reason: 'TENANT_MISMATCH' });
      continue;
    }

    const opRef = db.collection('tenants').doc(tenantId).collection('sync_operations').doc(op.idempotencyKey);
    const entityRef = db.collection('tenants').doc(tenantId).collection(op.entityType).doc(op.entityId);

    const outcome = await db.runTransaction(async (tx) => {
      const processedSnap = await tx.get(opRef);
      const remoteSnap = await tx.get(entityRef);

      const decision = evaluateSyncOperation({
        op,
        alreadyProcessedVersion: processedSnap.exists ? Number(processedSnap.data()?.appliedVersion ?? 1) : null,
        remoteRecord: remoteSnap.exists ? (remoteSnap.data() as Record<string, unknown>) : null,
      });

      if (decision.status === 'already_processed' || decision.status === 'rejected') {
        return decision;
      }

      if (decision.status === 'conflict') {
        const conflictId = crypto.randomUUID();
        const conflictRef = db.collection('tenants').doc(tenantId).collection('sync_conflicts').doc(conflictId);
        tx.set(conflictRef, {
          id: conflictId,
          tenantId,
          entityType: op.entityType,
          entityId: op.entityId,
          localVersion: op.baseVersion,
          remoteVersion: decision.remoteVersion,
          localSnapshot: op.payload,
          remoteSnapshot: remoteSnap.data() ?? null,
          reason: decision.reason,
          status: 'pending_review',
          createdBy: request.auth!.uid,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.set(opRef, {
          operationId: op.operationId,
          status: 'conflict',
          conflictId,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { ...decision, conflictId };
      }

      const nextPayload = {
        ...op.payload,
        id: op.entityId,
        tenantId,
        recordVersion: decision.newVersion,
        syncStatus: 'synced',
        updatedBy: request.auth!.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (op.operation === 'delete') {
        tx.set(
          entityRef,
          {
            ...nextPayload,
            deletedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      } else {
        tx.set(entityRef, nextPayload, { merge: true });
      }

      tx.set(opRef, {
        operationId: op.operationId,
        entityType: op.entityType,
        entityId: op.entityId,
        appliedVersion: decision.newVersion,
        status: 'applied',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return decision;
    });

    results.push({ operationId: op.operationId, ...outcome });
  }

  await writeAuditLog({
    tenantId,
    actorId: request.auth.uid,
    actorRole: membership.role,
    action: 'SYNC_BATCH_INGEST',
    entityType: 'sync_batch',
    entityId: operations[0].operationId,
    sourceDevice: operations[0].deviceId ?? 'unknown',
    afterSummary: { count: operations.length },
  });

  return { results };
});

/**
 * 2. Atomic Payment Recording (Idempotent by paymentReference)
 */
export const recordPaymentAtomic = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const { tenantId, invoiceId, shiftId, paymentReference, amount, method, type } = request.data as {
    tenantId: string;
    invoiceId: string;
    shiftId: string;
    paymentReference: string;
    amount: number;
    method: 'cash' | 'card' | 'transfer';
    type: 'payment' | 'refund';
  };

  if (!tenantId || !invoiceId || !paymentReference || typeof amount !== 'number' || amount <= 0) {
    throw new HttpsError('invalid-argument', 'Valid invoiceId, paymentReference, and positive amount required.');
  }

  const membership = await assertActiveMember(tenantId, request.auth.uid, [
    'clinic_owner',
    'clinic_manager',
    'accountant',
    'receptionist',
  ]);

  const refKeyDoc = db.collection('tenants').doc(tenantId).collection('payment_refs').doc(paymentReference);
  const invoiceRef = db.collection('tenants').doc(tenantId).collection('invoices').doc(invoiceId);
  const shiftRef = db.collection('tenants').doc(tenantId).collection('cashbox_shifts').doc(shiftId);

  const result = await db.runTransaction(async (tx) => {
    const existingRef = await tx.get(refKeyDoc);
    if (existingRef.exists) {
      return { idempotent: true, paymentId: existingRef.data()?.paymentId };
    }

    const invoiceSnap = await tx.get(invoiceRef);
    if (!invoiceSnap.exists) {
      throw new HttpsError('not-found', 'Invoice not found.');
    }
    const invoice = invoiceSnap.data()!;
    if (invoice.status === 'void') {
      throw new HttpsError('failed-precondition', 'Cannot record payment on a void invoice.');
    }

    const shiftSnap = await tx.get(shiftRef);
    if (!shiftSnap.exists || shiftSnap.data()?.status !== 'open') {
      throw new HttpsError('failed-precondition', 'Target cashbox shift is not open.');
    }

    const delta = type === 'refund' ? -amount : amount;
    const newPaid = Math.max(0, Number(invoice.paidAmount ?? 0) + delta);
    const totalDue = Number(invoice.totalDue ?? 0);
    const newRemaining = Math.max(0, totalDue - newPaid);
    const nextStatus = newRemaining === 0 ? 'paid' : newPaid > 0 ? 'partially_paid' : 'issued';

    const paymentId = crypto.randomUUID();
    const paymentRef = db.collection('tenants').doc(tenantId).collection('payments').doc(paymentId);

    tx.set(paymentRef, {
      id: paymentId,
      tenantId,
      invoiceId,
      patientId: invoice.patientId,
      shiftId,
      paymentReference,
      amount,
      currency: invoice.currency ?? 'YER',
      method,
      type,
      collectedBy: request.auth!.uid,
      createdBy: request.auth!.uid,
      updatedBy: request.auth!.uid,
      schemaVersion: 1,
      recordVersion: 1,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(refKeyDoc, { paymentId, createdAt: admin.firestore.FieldValue.serverTimestamp() });
    tx.update(invoiceRef, {
      paidAmount: newPaid,
      remainingAmount: newRemaining,
      status: nextStatus,
      recordVersion: Number(invoice.recordVersion ?? 1) + 1,
      updatedBy: request.auth!.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (method === 'cash') {
      const cashField = type === 'refund' ? 'totalCashOut' : 'totalCashIn';
      tx.update(shiftRef, {
        [cashField]: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { idempotent: false, paymentId, status: nextStatus, remainingAmount: newRemaining };
  });

  await writeAuditLog({
    tenantId,
    actorId: request.auth.uid,
    actorRole: membership.role,
    action: type === 'refund' ? 'PAYMENT_REFUND_RECORDED' : 'PAYMENT_RECORDED',
    entityType: 'payments',
    entityId: String(result.paymentId),
    sourceDevice: 'cloud_function',
    afterSummary: { invoiceId, amount, method, idempotent: result.idempotent },
  });

  return result;
});

/**
 * 3. External Laboratory Webhook Gateway (Verified + Idempotent + Never Auto-Approved)
 */
export const ingestExternalLabWebhook = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'METHOD_NOT_ALLOWED' });
    return;
  }

  const signature = req.header('x-cms-lab-signature');
  const tenantId = req.header('x-cms-tenant-id');
  const labId = req.header('x-cms-lab-id');

  if (!signature || !tenantId || !labId) {
    res.status(401).json({ error: 'MISSING_LAB_AUTH_HEADERS' });
    return;
  }

  const integrationSnap = await db
    .collection('tenants')
    .doc(tenantId)
    .collection('integrations')
    .doc(labId)
    .get();

  if (!integrationSnap.exists || integrationSnap.data()?.active !== true) {
    res.status(403).json({ error: 'LAB_INTEGRATION_NOT_ACTIVE' });
    return;
  }

  const sharedSecret = String(integrationSnap.data()?.webhookSecretHash ?? '');
  const expectedSig = crypto
    .createHmac('sha256', sharedSecret)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (!sharedSecret || signature !== expectedSig) {
    res.status(403).json({ error: 'INVALID_WEBHOOK_SIGNATURE' });
    return;
  }

  const { eventId, orderNumber, structuredValues, attachmentPath } = req.body as {
    eventId: string;
    orderNumber: string;
    structuredValues?: Array<Record<string, unknown>>;
    attachmentPath?: string;
  };

  if (!eventId || !orderNumber) {
    res.status(400).json({ error: 'MISSING_EVENT_OR_ORDER' });
    return;
  }

  const eventRef = db.collection('tenants').doc(tenantId).collection('laboratory_events').doc(eventId);
  const existingEvent = await eventRef.get();
  if (existingEvent.exists) {
    res.status(200).json({ status: 'already_processed', resultId: existingEvent.data()?.resultId });
    return;
  }

  const orderQuery = await db
    .collection('tenants')
    .doc(tenantId)
    .collection('lab_orders')
    .where('orderNumber', '==', orderNumber)
    .limit(1)
    .get();

  if (orderQuery.empty) {
    res.status(404).json({ error: 'LAB_ORDER_NOT_FOUND' });
    return;
  }

  const orderDoc = orderQuery.docs[0];
  const order = orderDoc.data();
  const resultId = crypto.randomUUID();

  await db.runTransaction(async (tx) => {
    tx.set(db.collection('tenants').doc(tenantId).collection('lab_results').doc(resultId), {
      id: resultId,
      tenantId,
      orderId: order.id,
      patientId: order.patientId,
      visitId: order.visitId,
      laboratoryId: labId,
      source: 'api',
      structuredValues: structuredValues ?? [],
      originalFileName: attachmentPath ?? null,
      reviewStatus: 'pending_review', // SRS §6.8: Never auto-approve without human doctor verification
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      receivedBy: `lab_api:${labId}`,
      createdBy: `lab_api:${labId}`,
      updatedBy: `lab_api:${labId}`,
      schemaVersion: 1,
      recordVersion: 1,
    });

    tx.set(eventRef, {
      id: eventId,
      laboratoryId: labId,
      orderId: order.id,
      resultId,
      status: 'ingested',
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const notifId = crypto.randomUUID();
    tx.set(db.collection('tenants').doc(tenantId).collection('notifications').doc(notifId), {
      id: notifId,
      tenantId,
      targetUserId: order.doctorId,
      type: 'lab_result_received',
      title: 'وصول نتيجة فحص مخبري',
      body: `تم استلام نتيجة الطلب رقم ${orderNumber} وهي بانتظار المراجعة والاعتماد.`,
      entityType: 'lab_results',
      entityId: resultId,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  res.status(201).json({ status: 'ingested', resultId });
});

/**
 * 4. Provision Member & Custom Claims (Server-Verified RBAC)
 */
export const provisionTenantMembership = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const { tenantId, targetUid, role, branchIds, active } = request.data as {
    tenantId: string;
    targetUid: string;
    role: string;
    branchIds: string[];
    active: boolean;
  };

  if (!ALLOWED_ROLES.has(role)) {
    throw new HttpsError('invalid-argument', 'Unsupported RBAC role.');
  }

  const caller = await assertActiveMember(tenantId, request.auth.uid, ['super_admin', 'clinic_owner', 'clinic_manager']);

  await db
    .collection('tenants')
    .doc(tenantId)
    .collection('memberships')
    .doc(targetUid)
    .set(
      {
        uid: targetUid,
        tenantId,
        role,
        branchIds: branchIds ?? ['main-branch'],
        active: active !== false,
        updatedBy: request.auth.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  await admin.auth().setCustomUserClaims(targetUid, {
    tenantId,
    role,
    active: active !== false,
  });

  await writeAuditLog({
    tenantId,
    actorId: request.auth.uid,
    actorRole: caller.role,
    action: 'MEMBERSHIP_PROVISIONED',
    entityType: 'memberships',
    entityId: targetUid,
    sourceDevice: 'cloud_function',
    afterSummary: { role, active: active !== false },
  });

  return { ok: true };
});
