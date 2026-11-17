import 'base_record.dart';

class InvoiceRecord extends BaseCmsRecord {
  const InvoiceRecord({
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
    required this.invoiceNumber,
    required this.patientId,
    this.visitId,
    required this.status,
    required this.clinicServicesSubtotal,
    required this.externalLabPassThrough,
    required this.discountAmount,
    required this.totalDue,
    required this.paidAmount,
    this.currency = 'YER',
    this.discountAuthorizedBy,
  });

  final String invoiceNumber;
  final String patientId;
  final String? visitId;
  final String status; // draft | issued | partially_paid | paid | void
  final double clinicServicesSubtotal;
  final double externalLabPassThrough;
  final double discountAmount;
  final double totalDue;
  final double paidAmount;
  final String currency;
  final String? discountAuthorizedBy;

  double get remainingAmount => (totalDue - paidAmount).clamp(0, double.infinity);
}

class PaymentRecord extends BaseCmsRecord {
  const PaymentRecord({
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
    required this.invoiceId,
    required this.patientId,
    required this.shiftId,
    required this.paymentReference,
    required this.receiptNumber,
    required this.amount,
    required this.method,
    required this.type,
    this.currency = 'YER',
  });

  final String invoiceId;
  final String patientId;
  final String shiftId;
  final String paymentReference; // Unique idempotency key preventing duplicate collection
  final String receiptNumber;
  final double amount;
  final String method; // cash | card | transfer
  final String type; // payment | refund
  final String currency;
}

class CashboxShiftRecord extends BaseCmsRecord {
  const CashboxShiftRecord({
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
    required this.cashierId,
    required this.openedAt,
    this.closedAt,
    required this.openingBalance,
    required this.totalCashIn,
    required this.totalCashOut,
    this.actualCountedBalance,
    required this.status,
  });

  final String cashierId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingBalance;
  final double totalCashIn;
  final double totalCashOut;
  final double? actualCountedBalance;
  final String status; // open | closed

  double get expectedClosingBalance => openingBalance + totalCashIn - totalCashOut;
  double? get variance =>
      actualCountedBalance == null ? null : actualCountedBalance! - expectedClosingBalance;
}
