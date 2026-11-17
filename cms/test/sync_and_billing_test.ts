import test from 'node:test';
import assert from 'node:assert/strict';
import {
  evaluateSyncOperation,
  calculateInvoiceAllocation,
  SyncEnvelope,
} from '../firebase/functions/src/sync_engine.ts';

function makeOp(overrides: Partial<SyncEnvelope> = {}): SyncEnvelope {
  return {
    operationId: 'op-001',
    idempotencyKey: 'patients:pat-1:1:op-001',
    tenantId: 'clinic-sanaa-001',
    entityType: 'patients',
    entityId: 'pat-1',
    operation: 'update',
    baseVersion: 1,
    payload: { fullName: 'أحمد صالح', phone: '777123456' },
    actorId: 'user-rec-1',
    deviceId: 'win-reception-1',
    occurredAt: '2026-11-17T10:00:00Z',
    ...overrides,
  };
}

test('Sync idempotency returns already_processed when idempotencyKey exists', () => {
  const decision = evaluateSyncOperation({
    op: makeOp(),
    alreadyProcessedVersion: 3,
    remoteRecord: { recordVersion: 3 },
  });
  assert.deepEqual(decision, { status: 'already_processed', existingVersion: 3 });
});

test('Sensitive clinical record rejects blind Last-Write-Wins on version mismatch', () => {
  const decision = evaluateSyncOperation({
    op: makeOp({
      entityType: 'consultations',
      entityId: 'cons-100',
      baseVersion: 1,
    }),
    alreadyProcessedVersion: null,
    remoteRecord: { recordVersion: 2, isDraft: true },
  });
  assert.equal(decision.status, 'conflict');
  if (decision.status === 'conflict') {
    assert.equal(decision.reason, 'VERSION_MISMATCH_ON_SENSITIVE_ENTITY');
    assert.equal(decision.remoteVersion, 2);
  }
});

test('Finalized visit cannot be silently overwritten during offline sync', () => {
  const decision = evaluateSyncOperation({
    op: makeOp({
      entityType: 'visits',
      entityId: 'vis-200',
      baseVersion: 2,
    }),
    alreadyProcessedVersion: null,
    remoteRecord: { recordVersion: 2, status: 'finalized' },
  });
  assert.equal(decision.status, 'conflict');
  if (decision.status === 'conflict') {
    assert.equal(decision.reason, 'TERMINAL_STATE_MODIFICATION_REQUIRES_REVIEW');
  }
});

test('Sequential non-conflicting update advances recordVersion monotonically', () => {
  const decision = evaluateSyncOperation({
    op: makeOp({ baseVersion: 2 }),
    alreadyProcessedVersion: null,
    remoteRecord: { recordVersion: 2 },
  });
  assert.deepEqual(decision, { status: 'applied', newVersion: 3 });
});

test('Financial allocation separates external lab fees from clinic revenue by default', () => {
  const withoutContract = calculateInvoiceAllocation({
    clinicServicesSubtotal: 5000,
    externalLabFeeAmount: 3500,
    hasContractualLabAgreement: false,
    discountAmount: 500,
  });
  assert.deepEqual(withoutContract, {
    clinicRevenueTotal: 4500,
    externalLabPassThrough: 3500,
    grandTotalDue: 8000,
  });

  const withContract = calculateInvoiceAllocation({
    clinicServicesSubtotal: 5000,
    externalLabFeeAmount: 3500,
    hasContractualLabAgreement: true,
    discountAmount: 500,
  });
  assert.deepEqual(withContract, {
    clinicRevenueTotal: 8000,
    externalLabPassThrough: 0,
    grandTotalDue: 8000,
  });
});
