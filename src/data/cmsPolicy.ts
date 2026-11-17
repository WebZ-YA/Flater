export type ClinicRoleCode =
  | 'super_admin'
  | 'clinic_owner'
  | 'clinic_manager'
  | 'receptionist'
  | 'doctor'
  | 'nurse'
  | 'accountant'
  | 'lab_coordinator'
  | 'staff';

export interface RoleDefinition {
  code: ClinicRoleCode;
  labelAr: string;
  permissions: string[];
}

export const CLINIC_ROLES: RoleDefinition[] = [
  {
    code: 'clinic_owner',
    labelAr: 'مالك العيادة',
    permissions: [
      'patients.read',
      'patients.write',
      'patients.archive',
      'appointments.manage',
      'queue.manage',
      'consultation.write',
      'consultation.finalize',
      'lab_orders.create',
      'lab_results.upload',
      'lab_results.approve',
      'prescriptions.write',
      'invoices.write',
      'payments.record',
      'discounts.authorize',
      'cashbox.close',
      'sync.resolve_conflict',
      'audit.read',
    ],
  },
  {
    code: 'clinic_manager',
    labelAr: 'مدير العيادة',
    permissions: [
      'patients.read',
      'patients.write',
      'patients.archive',
      'appointments.manage',
      'queue.manage',
      'discounts.authorize',
      'sync.resolve_conflict',
      'audit.read',
    ],
  },
  {
    code: 'receptionist',
    labelAr: 'الاستقبال والسكرتارية',
    permissions: [
      'patients.read',
      'patients.write',
      'patients.archive',
      'appointments.manage',
      'queue.manage',
      'lab_results.upload',
      'invoices.write',
      'payments.record',
    ],
  },
  {
    code: 'doctor',
    labelAr: 'الطبيب',
    permissions: [
      'patients.read',
      'appointments.manage',
      'queue.manage',
      'consultation.write',
      'consultation.finalize',
      'lab_orders.create',
      'lab_results.approve',
      'prescriptions.write',
      'sync.resolve_conflict',
    ],
  },
  {
    code: 'nurse',
    labelAr: 'التمريض',
    permissions: ['patients.read', 'queue.manage', 'consultation.write'],
  },
  {
    code: 'accountant',
    labelAr: 'المحاسب',
    permissions: [
      'patients.read',
      'invoices.write',
      'payments.record',
      'discounts.authorize',
      'cashbox.close',
      'sync.resolve_conflict',
      'audit.read',
    ],
  },
  {
    code: 'lab_coordinator',
    labelAr: 'منسق المختبر',
    permissions: ['patients.read', 'lab_results.upload'],
  },
  {
    code: 'super_admin',
    labelAr: 'مدير المنصة',
    permissions: ['audit.read'],
  },
  {
    code: 'staff',
    labelAr: 'موظف',
    permissions: ['patients.read'],
  },
];

export function hasRolePermission(role: ClinicRoleCode, perm: string): boolean {
  const def = CLINIC_ROLES.find((r) => r.code === role);
  return def ? def.permissions.includes(perm) : false;
}

export function formatYER(amount: number): string {
  return `${new Intl.NumberFormat('ar-YE').format(amount)} ر.ي`;
}
