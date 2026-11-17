/// SRS §6.12: 9-role RBAC system with granular customizable permissions.
enum ClinicRole {
  superAdmin('super_admin', 'مدير المنصة'),
  clinicOwner('clinic_owner', 'مالك العيادة'),
  clinicManager('clinic_manager', 'مدير العيادة'),
  receptionist('receptionist', 'الاستقبال والسكرتارية'),
  doctor('doctor', 'الطبيب'),
  nurse('nurse', 'التمريض'),
  accountant('accountant', 'المحاسب'),
  labCoordinator('lab_coordinator', 'منسق المختبر'),
  staff('staff', 'موظف');

  const ClinicRole(this.code, this.arabicLabel);
  final String code;
  final String arabicLabel;

  static ClinicRole fromCode(String code) {
    return ClinicRole.values.firstWhere(
      (r) => r.code == code,
      orElse: () => ClinicRole.staff,
    );
  }
}

enum ClinicPermission {
  tenantManage('tenant.manage'),
  usersManage('users.manage'),
  patientsRead('patients.read'),
  patientsWrite('patients.write'),
  patientsArchive('patients.archive'),
  appointmentsManage('appointments.manage'),
  queueManage('queue.manage'),
  vitalsWrite('vitals.write'),
  consultationWrite('consultation.write'),
  consultationFinalize('consultation.finalize'),
  labOrdersCreate('lab_orders.create'),
  labResultsUpload('lab_results.upload'),
  labResultsApprove('lab_results.approve'),
  prescriptionsWrite('prescriptions.write'),
  archiveManage('archive.manage'),
  invoicesWrite('invoices.write'),
  paymentsRecord('payments.record'),
  discountsAuthorize('discounts.authorize'),
  expensesManage('expenses.manage'),
  cashboxClose('cashbox.close'),
  reportsFinancial('reports.financial'),
  reportsClinical('reports.clinical'),
  syncResolveConflict('sync.resolve_conflict'),
  auditRead('audit.read');

  const ClinicPermission(this.key);
  final String key;
}

class RbacPolicyEngine {
  static final Map<ClinicRole, Set<ClinicPermission>> defaultRoleMatrix = {
    ClinicRole.superAdmin: {
      ClinicPermission.tenantManage,
      ClinicPermission.usersManage,
      ClinicPermission.reportsFinancial,
      ClinicPermission.reportsClinical,
      ClinicPermission.auditRead,
    },
    ClinicRole.clinicOwner: ClinicPermission.values.toSet(),
    ClinicRole.clinicManager: {
      ClinicPermission.usersManage,
      ClinicPermission.patientsRead,
      ClinicPermission.patientsWrite,
      ClinicPermission.patientsArchive,
      ClinicPermission.appointmentsManage,
      ClinicPermission.queueManage,
      ClinicPermission.archiveManage,
      ClinicPermission.discountsAuthorize,
      ClinicPermission.expensesManage,
      ClinicPermission.reportsFinancial,
      ClinicPermission.reportsClinical,
      ClinicPermission.syncResolveConflict,
      ClinicPermission.auditRead,
    },
    ClinicRole.receptionist: {
      // SRS §4: Receptionist & Secretary combined in v1, separable via permissions
      ClinicPermission.patientsRead,
      ClinicPermission.patientsWrite,
      ClinicPermission.patientsArchive,
      ClinicPermission.appointmentsManage,
      ClinicPermission.queueManage,
      ClinicPermission.archiveManage,
      ClinicPermission.labResultsUpload,
      ClinicPermission.invoicesWrite,
      ClinicPermission.paymentsRecord,
    },
    ClinicRole.doctor: {
      ClinicPermission.patientsRead,
      ClinicPermission.appointmentsManage,
      ClinicPermission.queueManage,
      ClinicPermission.vitalsWrite,
      ClinicPermission.consultationWrite,
      ClinicPermission.consultationFinalize,
      ClinicPermission.labOrdersCreate,
      ClinicPermission.labResultsApprove,
      ClinicPermission.prescriptionsWrite,
      ClinicPermission.archiveManage,
      ClinicPermission.reportsClinical,
      ClinicPermission.syncResolveConflict,
    },
    ClinicRole.nurse: {
      ClinicPermission.patientsRead,
      ClinicPermission.queueManage,
      ClinicPermission.vitalsWrite,
      ClinicPermission.archiveManage,
    },
    ClinicRole.accountant: {
      ClinicPermission.patientsRead,
      ClinicPermission.invoicesWrite,
      ClinicPermission.paymentsRecord,
      ClinicPermission.discountsAuthorize,
      ClinicPermission.expensesManage,
      ClinicPermission.cashboxClose,
      ClinicPermission.reportsFinancial,
      ClinicPermission.syncResolveConflict,
      ClinicPermission.auditRead,
    },
    ClinicRole.labCoordinator: {
      ClinicPermission.patientsRead,
      ClinicPermission.labResultsUpload,
      ClinicPermission.archiveManage,
    },
    ClinicRole.staff: {
      ClinicPermission.patientsRead,
    },
  };

  static bool hasPermission({
    required ClinicRole role,
    required ClinicPermission permission,
    List<String> customGranted = const [],
    List<String> customRevoked = const [],
  }) {
    if (customRevoked.contains(permission.key)) {
      return false;
    }
    if (customGranted.contains(permission.key)) {
      return true;
    }
    return defaultRoleMatrix[role]?.contains(permission) ?? false;
  }
}
