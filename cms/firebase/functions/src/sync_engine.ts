export const SENSITIVE_CONFLICT_ENTITIES = new Set([
  'patients',
  'visits',
  'consultations',
  'lab_orders',
  'lab_results',
  'prescriptions',
  'invoices',
  'payments',
  'expenses',
  'cashbox_shifts',
]);

export type SyncOperationType = 'create' | 'update' | 'delete';

export interface SyncEnvelope {
  operationId: string;
  idempotencyKey: string;
  tenantId: string;
  entityType: string;
  entityId: string;
  operation: SyncOperationType;
  baseVersion: number;
  payload: Record<string, unknown>;
  actorId: string;
  deviceId: string;
  occurredAt: string;
}

export type SyncDecision =
  | { status: 'applied'; newVersion: number }
  | { status: 'already_processed'; existingVersion: number }
  | { status: 'conflict'; reason: string; remoteVersion: number }
  | { status: 'rejected'; reason: string };

/**
 * Evaluates an incoming Outbox operation against current remote state.
 * Enforces SRS §11.4: NEVER apply blind Last-Write-Wins to clinical or financial records.
 */
export function evaluateSyncOperation(params: {
  op: SyncEnvelope;
  alreadyProcessedVersion: number | null;
  remoteRecord: Record<string, unknown> | null;
}): SyncDecision {
  const { op, alreadyProcessedVersion, remoteRecord } = params;

  if (alreadyProcessedVersion !== null) {
    return {
      status: 'already_processed',
      existingVersion: alreadyProcessedVersion,
    };
  }

  if (!op.idempotencyKey || !op.operationId || !op.tenantId || !op.entityId) {
    return { status: 'rejected', reason: 'MISSING_REQUIRED_SYNC_KEYS' };
  }

  if (op.operation === 'create') {
    if (remoteRecord !== null) {
      const remoteVersion = Number(remoteRecord.recordVersion ?? 1);
      if (SENSITIVE_CONFLICT_ENTITIES.has(op.entityType)) {
        return {
          status: 'conflict',
          reason: 'DUPLICATE_CREATE_ON_SENSITIVE_ENTITY',
          remoteVersion,
        };
      }
      return { status: 'applied', newVersion: remoteVersion + 1 };
    }
    return { status: 'applied', newVersion: 1 };
  }

  // Update or tombstone delete
  if (remoteRecord === null) {
    if (op.operation === 'delete') {
      return { status: 'applied', newVersion: 1 };
    }
    return { status: 'rejected', reason: 'TARGET_RECORD_NOT_FOUND' };
  }

  const remoteVersion = Number(remoteRecord.recordVersion ?? 1);

  // Check terminal lock on finalized clinical / voided financial records
  if (
    (op.entityType === 'visits' && remoteRecord.status === 'finalized') ||
    (op.entityType === 'consultations' && remoteRecord.isDraft === false) ||
    (op.entityType === 'invoices' && remoteRecord.status === 'void')
  ) {
    return {
      status: 'conflict',
      reason: 'TERMINAL_STATE_MODIFICATION_REQUIRES_REVIEW',
      remoteVersion,
    };
  }

  if (remoteVersion > op.baseVersion) {
    if (SENSITIVE_CONFLICT_ENTITIES.has(op.entityType)) {
      return {
        status: 'conflict',
        reason: 'VERSION_MISMATCH_ON_SENSITIVE_ENTITY',
        remoteVersion,
      };
    }
  }

  return { status: 'applied', newVersion: remoteVersion + 1 };
}

export interface InvoiceAllocationInput {
  clinicServicesSubtotal: number;
  externalLabFeeAmount: number;
  hasContractualLabAgreement: boolean;
  discountAmount: number;
}

export interface InvoiceAllocationResult {
  clinicRevenueTotal: number;
  externalLabPassThrough: number;
  grandTotalDue: number;
}

/**
 * SRS §8.10: External lab fees must be separated from clinic revenue unless
 * an explicit contractual agreement exists.
 */
export function calculateInvoiceAllocation(
  input: InvoiceAllocationInput,
): InvoiceAllocationResult {
  const clinicBeforeDiscount = Math.max(0, input.clinicServicesSubtotal);
  const safeDiscount = Math.min(Math.max(0, input.discountAmount), clinicBeforeDiscount);
  const clinicNet = clinicBeforeDiscount - safeDiscount;
  const labFee = Math.max(0, input.externalLabFeeAmount);

  if (input.hasContractualLabAgreement) {
    return {
      clinicRevenueTotal: clinicNet + labFee,
      externalLabPassThrough: 0,
      grandTotalDue: clinicNet + labFee,
    };
  }

  return {
    clinicRevenueTotal: clinicNet,
    externalLabPassThrough: labFee,
    grandTotalDue: clinicNet + labFee,
  };
}
