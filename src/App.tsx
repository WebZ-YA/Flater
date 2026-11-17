import React, { useMemo, useState } from 'react';
import {
  Activity,
  Archive,
  ClipboardCheck,
  FileText,
  FlaskConical,
  LayoutDashboard,
  Moon,
  Pill,
  Receipt,
  RefreshCw,
  Search,
  ShieldCheck,
  Sun,
  Users,
  Wifi,
  WifiOff,
  AlertTriangle,
  CheckCircle2,
  Plus,
} from 'lucide-react';
import {
  calculateInvoiceAllocation,
  evaluateSyncOperation,
} from '../cms/firebase/functions/src/sync_engine';
import { CLINIC_ROLES, ClinicRoleCode, formatYER, hasRolePermission } from './data/cmsPolicy';

type NavSection =
  | 'dashboard'
  | 'patients'
  | 'queue'
  | 'consultation'
  | 'labs'
  | 'billing'
  | 'sync'
  | 'audit'
  | 'architecture';

interface PatientItem {
  id: string;
  medicalNumber: string;
  fullName: string;
  phone: string;
  gender: 'male' | 'female';
  allergies: string[];
  archived: boolean;
  recordVersion: number;
}

interface QueueItem {
  id: string;
  ticketCode: string;
  patientId: string;
  patientName: string;
  visitType: string;
  status: 'waiting' | 'called' | 'in_consultation' | 'completed';
}

interface LabOrderItem {
  id: string;
  orderNumber: string;
  patientName: string;
  tests: string;
  labName: string;
  reviewStatus: 'pending_review' | 'approved';
}

interface OutboxItem {
  operationId: string;
  idempotencyKey: string;
  entityType: string;
  entityId: string;
  baseVersion: number;
  remoteVersion: number;
  summary: string;
  status: 'pending' | 'synced' | 'conflict';
  conflictReason?: string;
}

interface AuditEntry {
  id: string;
  actorRole: string;
  action: string;
  entity: string;
  occurredAt: string;
}

const INITIAL_PATIENTS: PatientItem[] = [
  {
    id: 'pat-101',
    medicalNumber: 'PAT-000001',
    fullName: 'أحمد صالح المنصور',
    phone: '777123456',
    gender: 'male',
    allergies: ['البنسلين'],
    archived: false,
    recordVersion: 1,
  },
  {
    id: 'pat-102',
    medicalNumber: 'PAT-000002',
    fullName: 'فاطمة عبد الله الحمادي',
    phone: '773987654',
    gender: 'female',
    allergies: [],
    archived: false,
    recordVersion: 1,
  },
];

const INITIAL_QUEUE: QueueItem[] = [
  {
    id: 'q-1',
    ticketCode: 'Q-001',
    patientId: 'pat-101',
    patientName: 'أحمد صالح المنصور',
    visitType: 'استشارة أولى',
    status: 'called',
  },
  {
    id: 'q-2',
    ticketCode: 'Q-002',
    patientId: 'pat-102',
    patientName: 'فاطمة عبد الله الحمادي',
    visitType: 'متابعة',
    status: 'waiting',
  },
];

const INITIAL_LABS: LabOrderItem[] = [
  {
    id: 'lab-1',
    orderNumber: 'LAB-000001',
    patientName: 'أحمد صالح المنصور',
    tests: 'CBC, Fasting Blood Sugar',
    labName: 'مختبر العولقي التخصصي (إدخال يدوي)',
    reviewStatus: 'pending_review',
  },
];

export default function App() {
  const [darkMode, setDarkMode] = useState(false);
  const [activeNav, setActiveNav] = useState<NavSection>('dashboard');
  const [role, setRole] = useState<ClinicRoleCode>('clinic_owner');
  const [isOnline, setIsOnline] = useState(true);

  const [patients, setPatients] = useState<PatientItem[]>(INITIAL_PATIENTS);
  const [patientSearch, setPatientSearch] = useState('');
  const [newName, setNewName] = useState('');
  const [newPhone, setNewPhone] = useState('');
  const [newAllergy, setNewAllergy] = useState('');
  const [patientError, setPatientError] = useState<string | null>(null);

  const [queue, setQueue] = useState<QueueItem[]>(INITIAL_QUEUE);

  const [complaint, setComplaint] = useState('صداع متكرر مع إرهاق عام منذ 3 أيام');
  const [diagnosis, setDiagnosis] = useState('اشتباه ارتفاع ضغط الدم الأساسي');
  const [treatmentPlan, setTreatmentPlan] = useState('قياس ضغط الدم يومياً لمدة أسبوع وإجراء فحوصات مخبرية');
  const [visitFinalized, setVisitFinalized] = useState(false);

  const [labOrders, setLabOrders] = useState<LabOrderItem[]>(INITIAL_LABS);

  const [clinicFee, setClinicFee] = useState(5000);
  const [externalLabFee, setExternalLabFee] = useState(3500);
  const [discountAmount, setDiscountAmount] = useState(500);
  const [hasLabContract, setHasLabContract] = useState(false);
  const [paymentRecordedMsg, setPaymentRecordedMsg] = useState<string | null>(null);

  const [outbox, setOutbox] = useState<OutboxItem[]>([
    {
      operationId: 'op-local-101',
      idempotencyKey: 'patients:pat-101:1:op-local-101',
      entityType: 'patients',
      entityId: 'pat-101',
      baseVersion: 1,
      remoteVersion: 1,
      summary: 'تحديث بيانات العنوان للمريض PAT-000001',
      status: 'pending',
    },
    {
      operationId: 'op-local-102',
      idempotencyKey: 'consultations:cons-88:1:op-local-102',
      entityType: 'consultations',
      entityId: 'cons-88',
      baseVersion: 1,
      remoteVersion: 2,
      summary: 'تعديل تشخيص معاينة تم تحديثها على جهاز آخر',
      status: 'pending',
    },
  ]);

  const [auditLogs, setAuditLogs] = useState<AuditEntry[]>([
    {
      id: 'aud-1',
      actorRole: 'receptionist',
      action: 'PATIENT_CREATED',
      entity: 'PAT-000001',
      occurredAt: '2026-11-17 09:15',
    },
    {
      id: 'aud-2',
      actorRole: 'doctor',
      action: 'LAB_ORDER_ISSUED',
      entity: 'LAB-000001',
      occurredAt: '2026-11-17 09:42',
    },
  ]);

  const invoiceAllocation = useMemo(
    () =>
      calculateInvoiceAllocation({
        clinicServicesSubtotal: clinicFee,
        externalLabFeeAmount: externalLabFee,
        hasContractualLabAgreement: hasLabContract,
        discountAmount,
      }),
    [clinicFee, externalLabFee, hasLabContract, discountAmount],
  );

  const toggleTheme = () => {
    const next = !darkMode;
    setDarkMode(next);
    document.documentElement.classList.toggle('dark', next);
  };

  const appendAudit = (action: string, entity: string) => {
    setAuditLogs((prev) => [
      {
        id: `aud-${prev.length + 1}`,
        actorRole: role,
        action,
        entity,
        occurredAt: new Date().toISOString().slice(0, 16).replace('T', ' '),
      },
      ...prev,
    ]);
  };

  const handleAddPatient = (e: React.FormEvent) => {
    e.preventDefault();
    setPatientError(null);
    if (!hasRolePermission(role, 'patients.write')) {
      setPatientError('صلاحية الدور الحالي لا تسمح بتسجيل المرضى.');
      return;
    }
    const cleanName = newName.trim();
    const cleanPhone = newPhone.trim().replace(/\s+/g, '');
    if (cleanName.length < 2 || cleanPhone.length < 6) {
      setPatientError('يرجى إدخال الاسم الكامل ورقم هاتف صالح.');
      return;
    }
    if (patients.some((p) => p.phone === cleanPhone && !p.archived)) {
      setPatientError('تنبيه منع التكرار: يوجد ملف طبي مسجل مسبقاً بنفس رقم الهاتف.');
      return;
    }
    const nextNo = `PAT-${String(patients.length + 1).padStart(6, '0')}`;
    const newPat: PatientItem = {
      id: `pat-${patients.length + 101}`,
      medicalNumber: nextNo,
      fullName: cleanName,
      phone: cleanPhone,
      gender: 'male',
      allergies: newAllergy ? [newAllergy.trim()] : [],
      archived: false,
      recordVersion: 1,
    };
    setPatients((prev) => [newPat, ...prev]);
    setOutbox((prev) => [
      {
        operationId: `op-${Date.now()}`,
        idempotencyKey: `patients:${newPat.id}:1:${Date.now()}`,
        entityType: 'patients',
        entityId: newPat.id,
        baseVersion: 1,
        remoteVersion: 0,
        summary: `تسجيل مريض جديد ${nextNo}`,
        status: 'pending',
      },
      ...prev,
    ]);
    appendAudit('PATIENT_CREATED', nextNo);
    setNewName('');
    setNewPhone('');
    setNewAllergy('');
  };

  const handleSyncRun = () => {
    if (!isOnline) return;
    setOutbox((prev) =>
      prev.map((item) => {
        if (item.status === 'synced') return item;
        const decision = evaluateSyncOperation({
          op: {
            operationId: item.operationId,
            idempotencyKey: item.idempotencyKey,
            tenantId: 'clinic-sanaa-001',
            entityType: item.entityType,
            entityId: item.entityId,
            operation: item.remoteVersion === 0 ? 'create' : 'update',
            baseVersion: item.baseVersion,
            payload: { summary: item.summary },
            actorId: role,
            deviceId: 'web-workbench',
            occurredAt: new Date().toISOString(),
          },
          alreadyProcessedVersion: null,
          remoteRecord: item.remoteVersion === 0 ? null : { recordVersion: item.remoteVersion },
        });
        if (decision.status === 'conflict') {
          return { ...item, status: 'conflict', conflictReason: decision.reason };
        }
        if (decision.status === 'applied' || decision.status === 'already_processed') {
          return { ...item, status: 'synced' };
        }
        return item;
      }),
    );
    appendAudit('SYNC_CYCLE_EXECUTED', 'outbox_batch');
  };

  const handleResolveConflict = (opId: string) => {
    if (!hasRolePermission(role, 'sync.resolve_conflict')) return;
    setOutbox((prev) =>
      prev.map((item) => (item.operationId === opId ? { ...item, status: 'synced', conflictReason: undefined } : item)),
    );
    appendAudit('SYNC_CONFLICT_REVIEWED', opId);
  };

  const navItems: Array<{ id: NavSection; label: string; icon: React.ReactNode }> = [
    { id: 'dashboard', label: 'لوحة التحكم', icon: <LayoutDashboard className="w-4 h-4" /> },
    { id: 'patients', label: 'المرضى والملفات', icon: <Users className="w-4 h-4" /> },
    { id: 'queue', label: 'الطابور وشاشة الانتظار', icon: <Activity className="w-4 h-4" /> },
    { id: 'consultation', label: 'المعاينة والتشخيص', icon: <ClipboardCheck className="w-4 h-4" /> },
    { id: 'labs', label: 'المختبرات والنتائج', icon: <FlaskConical className="w-4 h-4" /> },
    { id: 'billing', label: 'الفواتير والصندوق', icon: <Receipt className="w-4 h-4" /> },
    { id: 'sync', label: 'المزامنة والتعارضات', icon: <RefreshCw className="w-4 h-4" /> },
    { id: 'audit', label: 'سجل التدقيق', icon: <ShieldCheck className="w-4 h-4" /> },
    { id: 'architecture', label: 'ملفات Flutter والمعمارية', icon: <FileText className="w-4 h-4" /> },
  ];

  const pendingCount = outbox.filter((o) => o.status !== 'synced').length;
  const conflictCount = outbox.filter((o) => o.status === 'conflict').length;
  const filteredPatients = patients.filter(
    (p) =>
      !p.archived &&
      (patientSearch === '' ||
        p.fullName.includes(patientSearch) ||
        p.phone.includes(patientSearch) ||
        p.medicalNumber.includes(patientSearch)),
  );

  return (
    <div className="min-h-screen flex bg-slate-50 text-slate-900 dark:bg-slate-950 dark:text-slate-100">
      {/* Sidebar (240px-260px) */}
      <aside className="w-64 shrink-0 border-l border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex flex-col justify-between p-4">
        <div className="space-y-6">
          <div className="px-2 pt-1">
            <div className="text-base font-bold text-teal-700 dark:text-teal-400">
              نظام إدارة العيادات الطبية
            </div>
            <div className="text-xs text-slate-500 dark:text-slate-400 mt-1">
              CMS · SRS v1.1 · Hybrid Local+Cloud
            </div>
          </div>

          <nav className="space-y-1">
            {navItems.map((item) => {
              const active = activeNav === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => setActiveNav(item.id)}
                  className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors whitespace-nowrap ${
                    active
                      ? 'bg-teal-700 text-white'
                      : 'text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800'
                  }`}
                >
                  {item.icon}
                  <span className="truncate">{item.label}</span>
                </button>
              );
            })}
          </nav>
        </div>

        <div className="border-t border-slate-200 dark:border-slate-800 pt-4 space-y-3">
          <div>
            <label className="block text-xs text-slate-500 dark:text-slate-400 mb-1">
              اختبار الصلاحيات حسب الدور (RBAC)
            </label>
            <select
              value={role}
              onChange={(e) => setRole(e.target.value as ClinicRoleCode)}
              className="w-full text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 px-2.5 py-2"
            >
              {CLINIC_ROLES.map((r) => (
                <option key={r.code} value={r.code}>
                  {r.labelAr}
                </option>
              ))}
            </select>
          </div>
        </div>
      </aside>

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top Bar Contract */}
        <header className="h-16 border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 px-6 flex items-center justify-between gap-6">
          <div className="text-sm text-slate-600 dark:text-slate-300 truncate">
            العيادة التخصصية النموذجية /{' '}
            <span className="font-semibold text-slate-900 dark:text-white">
              {navItems.find((n) => n.id === activeNav)?.label}
            </span>
          </div>

          <div className="flex items-center gap-3 shrink-0">
            <button
              onClick={() => setIsOnline((v) => !v)}
              className="inline-flex items-center gap-2 px-3 py-1.5 text-xs font-medium rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 whitespace-nowrap shrink-0"
            >
              {isOnline ? <Wifi className="w-3.5 h-3.5 text-emerald-600" /> : <WifiOff className="w-3.5 h-3.5 text-amber-600" />}
              <span>{isOnline ? 'متصل بالسحابة' : 'وضع محلي Offline'}</span>
            </button>

            <button
              onClick={toggleTheme}
              aria-label="تبديل المظهر"
              className="p-2 rounded-lg border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 shrink-0"
            >
              {darkMode ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
            </button>
          </div>
        </header>

        {/* Offline / Sync Alert Bar */}
        {(!isOnline || pendingCount > 0) && (
          <div className="px-6 py-2.5 bg-amber-50 dark:bg-amber-950/50 border-b border-amber-200 dark:border-amber-900 text-xs text-amber-900 dark:text-amber-200 flex items-center justify-between gap-4">
            <div className="flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 shrink-0" />
              <span>
                {isOnline
                  ? `توجد ${pendingCount} عمليات معلقة في Outbox (${conflictCount} تعارض يتطلب مراجعة).`
                  : `انقطاع الإنترنت: تستمر العمليات محلياً عبر SQLite/Drift — ${pendingCount} عمليات بانتظار المزامنة.`}
              </span>
            </div>
            <button
              onClick={() => setActiveNav('sync')}
              className="font-semibold underline whitespace-nowrap shrink-0"
            >
              فتح مركز المزامنة
            </button>
          </div>
        )}

        <main className="flex-1 p-6 max-w-6xl w-full mx-auto space-y-6">
          {activeNav === 'dashboard' && (
            <div className="space-y-6">
              <div>
                <h1 className="text-xl font-bold">لوحة التحكم التشغيلية</h1>
                <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
                  عرض حي لمؤشرات العيادة اليومية · العملة الافتراضية: الريال اليمني (YER)
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="p-4 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
                  <div className="text-xs text-slate-500 dark:text-slate-400">المرضى المسجلون</div>
                  <div className="text-2xl font-bold tabular-nums mt-1">{patients.length}</div>
                </div>
                <div className="p-4 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
                  <div className="text-xs text-slate-500 dark:text-slate-400">طابور الانتظار اليوم</div>
                  <div className="text-2xl font-bold tabular-nums mt-1">{queue.length}</div>
                </div>
                <div className="p-4 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
                  <div className="text-xs text-slate-500 dark:text-slate-400">نتائج مختبر بانتظار الاعتماد</div>
                  <div className="text-2xl font-bold tabular-nums mt-1">
                    {labOrders.filter((l) => l.reviewStatus === 'pending_review').length}
                  </div>
                </div>
                <div className="p-4 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
                  <div className="text-xs text-slate-500 dark:text-slate-400">إجمالي الفاتورة التجريبية</div>
                  <div className="text-2xl font-bold tabular-nums mt-1">
                    {formatYER(invoiceAllocation.grandTotalDue)}
                  </div>
                </div>
              </div>

              <div className="p-5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 space-y-3">
                <h2 className="text-base font-semibold">تنبيه هام حول بيئة التنفيذ</h2>
                <p className="text-sm text-slate-600 dark:text-slate-300 leading-relaxed">
                  هذه المعاينة التفاعلية تتيح اختبار منطق الصلاحيات (RBAC)، ومنع تكرار المرضى، وفصل رسوم المختبر الخارجي،
                  ومحرك كشف التعارضات (بدون Last-Write-Wins) في المتصفح مباشرة. بينما يقع المشروع الكامل بتقنيات{' '}
                  <span className="font-mono text-xs">Flutter + Dart + Drift + Local Server + Firebase</span> داخل المجلد{' '}
                  <span className="font-mono text-xs">/cms/</span>.
                </p>
              </div>
            </div>
          )}

          {activeNav === 'patients' && (
            <div className="space-y-6">
              <div className="flex flex-wrap items-center justify-between gap-4">
                <h1 className="text-xl font-bold">إدارة المرضى والملف الطبي</h1>
                <div className="relative w-72">
                  <Search className="w-4 h-4 absolute right-3 top-2.5 text-slate-400" />
                  <input
                    value={patientSearch}
                    onChange={(e) => setPatientSearch(e.target.value)}
                    placeholder="بحث بالاسم أو الهاتف أو PAT-..."
                    className="w-full pr-9 pl-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900"
                  />
                </div>
              </div>

              <form
                onSubmit={handleAddPatient}
                className="p-5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 grid grid-cols-1 md:grid-cols-4 gap-3 items-end"
              >
                <div>
                  <label className="block text-xs text-slate-500 mb-1">اسم المريض الكامل</label>
                  <input
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-500 mb-1">رقم الهاتف</label>
                  <input
                    value={newPhone}
                    onChange={(e) => setNewPhone(e.target.value)}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent font-mono"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-500 mb-1">الحساسية الدوائية</label>
                  <input
                    value={newAllergy}
                    onChange={(e) => setNewAllergy(e.target.value)}
                    placeholder="اختياري"
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent"
                  />
                </div>
                <button
                  type="submit"
                  className="inline-flex items-center justify-center gap-2 px-4 py-2 text-sm font-semibold rounded-lg bg-teal-700 text-white hover:bg-teal-800 whitespace-nowrap"
                >
                  <Plus className="w-4 h-4" />
                  <span>تسجيل مريض</span>
                </button>
                {patientError && (
                  <div className="md:col-span-4 text-xs text-red-600 dark:text-red-400">{patientError}</div>
                )}
              </form>

              <div className="rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 overflow-x-auto">
                <table className="w-full text-sm text-right">
                  <thead className="border-b border-slate-200 dark:border-slate-800 text-xs text-slate-500">
                    <tr>
                      <th className="py-3 px-4">الرقم الطبي</th>
                      <th className="py-3 px-4">الاسم الكامل</th>
                      <th className="py-3 px-4">الهاتف</th>
                      <th className="py-3 px-4">الحساسية</th>
                      <th className="py-3 px-4">إجراء</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                    {filteredPatients.map((p) => (
                      <tr key={p.id}>
                        <td className="py-3 px-4 font-mono">{p.medicalNumber}</td>
                        <td className="py-3 px-4 font-medium">{p.fullName}</td>
                        <td className="py-3 px-4 font-mono">{p.phone}</td>
                        <td className="py-3 px-4 text-slate-500">
                          {p.allergies.length > 0 ? p.allergies.join('، ') : 'لا يوجد'}
                        </td>
                        <td className="py-3 px-4">
                          <button
                            onClick={() => {
                              if (!hasRolePermission(role, 'patients.archive')) return;
                              setPatients((prev) =>
                                prev.map((item) => (item.id === p.id ? { ...item, archived: true } : item)),
                              );
                              appendAudit('PATIENT_ARCHIVED', p.medicalNumber);
                            }}
                            className="inline-flex items-center gap-1 text-xs text-slate-600 dark:text-slate-300 hover:text-red-600"
                          >
                            <Archive className="w-3.5 h-3.5" />
                            <span>أرشفة</span>
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {activeNav === 'queue' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h1 className="text-xl font-bold">طابور الانتظار وشاشة الاستدعاء</h1>
                <button
                  onClick={() => {
                    if (!hasRolePermission(role, 'queue.manage') || patients.length === 0) return;
                    const p = patients[0];
                    const code = `Q-${String(queue.length + 1).padStart(3, '0')}`;
                    setQueue((prev) => [
                      ...prev,
                      {
                        id: `q-${prev.length + 1}`,
                        ticketCode: code,
                        patientId: p.id,
                        patientName: p.fullName,
                        visitType: 'استشارة',
                        status: 'waiting',
                      },
                    ]);
                    appendAudit('QUEUE_TICKET_ISSUED', code);
                  }}
                  className="px-4 py-2 text-sm font-semibold rounded-lg bg-teal-700 text-white hover:bg-teal-800 whitespace-nowrap"
                >
                  إصدار تذكرة انتظار جديدة
                </button>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <div className="p-6 rounded-xl bg-slate-900 text-white border border-slate-800 flex flex-col justify-between min-h-56">
                  <div className="text-xs text-slate-400">شاشة الانتظار المستقلة — الرقم المستدعى حالياً</div>
                  <div className="text-5xl font-bold font-mono tracking-wider my-6">
                    {queue.find((q) => q.status === 'called')?.ticketCode ?? '---'}
                  </div>
                  <div className="text-sm text-slate-300">
                    {queue.find((q) => q.status === 'called')?.patientName ?? 'لا يوجد استدعاء حالي'}
                  </div>
                </div>

                <div className="rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 divide-y divide-slate-100 dark:divide-slate-800">
                  {queue.map((q) => (
                    <div key={q.id} className="p-4 flex items-center justify-between gap-4">
                      <div>
                        <div className="font-mono font-bold">{q.ticketCode}</div>
                        <div className="text-sm text-slate-600 dark:text-slate-300">
                          {q.patientName} · {q.visitType} · {q.status}
                        </div>
                      </div>
                      <button
                        onClick={() => {
                          if (!hasRolePermission(role, 'queue.manage')) return;
                          setQueue((prev) =>
                            prev.map((item) =>
                              item.id === q.id
                                ? { ...item, status: 'called' }
                                : item.status === 'called'
                                  ? { ...item, status: 'completed' }
                                  : item,
                            ),
                          );
                          appendAudit('QUEUE_PATIENT_CALLED', q.ticketCode);
                        }}
                        className="px-3 py-1.5 text-xs font-medium rounded-lg border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 whitespace-nowrap"
                      >
                        استدعاء للطبيب
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {activeNav === 'consultation' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div>
                  <h1 className="text-xl font-bold">المعاينة الطبية (VIS-000001)</h1>
                  <p className="text-xs text-slate-500 mt-1">
                    الحالة: {visitFinalized ? 'معتمدة ومقفلة ضد التعديل الصامت' : 'مسودة قيد المعاينة'}
                  </p>
                </div>
                {!visitFinalized && hasRolePermission(role, 'consultation.finalize') && (
                  <button
                    onClick={() => {
                      setVisitFinalized(true);
                      appendAudit('VISIT_FINALIZED', 'VIS-000001');
                    }}
                    className="px-4 py-2 text-sm font-semibold rounded-lg bg-teal-700 text-white hover:bg-teal-800 whitespace-nowrap"
                  >
                    اعتماد وإغلاق الزيارة
                  </button>
                )}
              </div>

              <div className="p-6 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 space-y-4">
                <div>
                  <label className="block text-xs text-slate-500 mb-1">الشكوى الرئيسية</label>
                  <input
                    disabled={visitFinalized || !hasRolePermission(role, 'consultation.write')}
                    value={complaint}
                    onChange={(e) => setComplaint(e.target.value)}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent disabled:opacity-60"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-500 mb-1">التشخيص الطبي</label>
                  <textarea
                    disabled={visitFinalized || !hasRolePermission(role, 'consultation.write')}
                    value={diagnosis}
                    onChange={(e) => setDiagnosis(e.target.value)}
                    rows={2}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent disabled:opacity-60"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-500 mb-1">خطة العلاج</label>
                  <textarea
                    disabled={visitFinalized || !hasRolePermission(role, 'consultation.write')}
                    value={treatmentPlan}
                    onChange={(e) => setTreatmentPlan(e.target.value)}
                    rows={2}
                    className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent disabled:opacity-60"
                  />
                </div>
              </div>
            </div>
          )}

          {activeNav === 'labs' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h1 className="text-xl font-bold">طلبات الفحوصات والمختبرات الخارجية</h1>
                {hasRolePermission(role, 'lab_orders.create') && (
                  <button
                    onClick={() => {
                      const num = `LAB-${String(labOrders.length + 1).padStart(6, '0')}`;
                      setLabOrders((prev) => [
                        ...prev,
                        {
                          id: `lab-${prev.length + 1}`,
                          orderNumber: num,
                          patientName: patients[0]?.fullName ?? 'مريض',
                          tests: 'Lipid Profile, HbA1c',
                          labName: 'مختبر الحياة المركزي (بوابة المختبر)',
                          reviewStatus: 'pending_review',
                        },
                      ]);
                      appendAudit('LAB_ORDER_ISSUED', num);
                    }}
                    className="px-4 py-2 text-sm font-semibold rounded-lg bg-teal-700 text-white hover:bg-teal-800 whitespace-nowrap"
                  >
                    إصدار طلب فحص جديد
                  </button>
                )}
              </div>

              <div className="rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 divide-y divide-slate-100 dark:divide-slate-800">
                {labOrders.map((o) => (
                  <div key={o.id} className="p-4 flex items-center justify-between gap-4">
                    <div>
                      <div className="font-mono font-bold">
                        {o.orderNumber} · {o.patientName}
                      </div>
                      <div className="text-sm text-slate-500">
                        {o.tests} · {o.labName} ·{' '}
                        {o.reviewStatus === 'approved' ? 'معتمدة من الطبيب' : 'بانتظار مراجعة الطبيب'}
                      </div>
                    </div>
                    {o.reviewStatus === 'pending_review' && hasRolePermission(role, 'lab_results.approve') && (
                      <button
                        onClick={() => {
                          setLabOrders((prev) =>
                            prev.map((item) => (item.id === o.id ? { ...item, reviewStatus: 'approved' } : item)),
                          );
                          appendAudit('LAB_RESULT_APPROVED', o.orderNumber);
                        }}
                        className="px-3 py-1.5 text-xs font-medium rounded-lg bg-teal-700 text-white whitespace-nowrap"
                      >
                        اعتماد الطبيب
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {activeNav === 'billing' && (
            <div className="space-y-6">
              <h1 className="text-xl font-bold">النظام المالي وفصل رسوم المختبرات الخارجية</h1>
              <div className="p-6 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="space-y-4">
                  <div>
                    <label className="block text-xs text-slate-500 mb-1">رسوم خدمات العيادة (ر.ي)</label>
                    <input
                      type="number"
                      value={clinicFee}
                      onChange={(e) => setClinicFee(Number(e.target.value))}
                      className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent font-mono"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-500 mb-1">رسوم المختبر الخارجي (ر.ي)</label>
                    <input
                      type="number"
                      value={externalLabFee}
                      onChange={(e) => setExternalLabFee(Number(e.target.value))}
                      className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent font-mono"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-500 mb-1">الخصم المصرح به (ر.ي)</label>
                    <input
                      type="number"
                      value={discountAmount}
                      onChange={(e) => setDiscountAmount(Number(e.target.value))}
                      className="w-full px-3 py-2 text-sm rounded-lg border border-slate-300 dark:border-slate-700 bg-transparent font-mono"
                    />
                  </div>
                  <label className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={hasLabContract}
                      onChange={(e) => setHasLabContract(e.target.checked)}
                    />
                    <span>توجد اتفاقية مالية تعاقدية لإدراج رسوم المختبر ضمن إيراد العيادة</span>
                  </label>
                </div>

                <div className="space-y-3 border-t md:border-t-0 md:border-r border-slate-200 dark:border-slate-800 pt-4 md:pt-0 md:pr-6">
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-500">إيراد العيادة الصافي:</span>
                    <span className="font-mono font-semibold">{formatYER(invoiceAllocation.clinicRevenueTotal)}</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-slate-500">رسوم مختبر خارجي مفصولة (Pass-Through):</span>
                    <span className="font-mono font-semibold">
                      {formatYER(invoiceAllocation.externalLabPassThrough)}
                    </span>
                  </div>
                  <div className="border-t border-slate-200 dark:border-slate-800 pt-3 flex justify-between text-base font-bold">
                    <span>إجمالي المستحق على الفاتورة:</span>
                    <span className="font-mono text-teal-700 dark:text-teal-400">
                      {formatYER(invoiceAllocation.grandTotalDue)}
                    </span>
                  </div>
                  {hasRolePermission(role, 'payments.record') && (
                    <button
                      onClick={() => {
                        const refCode = `PAY-${Date.now().toString().slice(-6)}`;
                        setPaymentRecordedMsg(`تم تسجيل الدفعة برقم مرجعي فريد مانع للتكرار: ${refCode}`);
                        appendAudit('PAYMENT_RECORDED', refCode);
                      }}
                      className="w-full mt-4 px-4 py-2.5 text-sm font-semibold rounded-lg bg-teal-700 text-white hover:bg-teal-800"
                    >
                      تحصيل دفعة برقم مرجعي فريد
                    </button>
                  )}
                  {paymentRecordedMsg && (
                    <div className="text-xs text-emerald-700 dark:text-emerald-400 flex items-center gap-1.5 pt-2">
                      <CheckCircle2 className="w-4 h-4" />
                      <span>{paymentRecordedMsg}</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {activeNav === 'sync' && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div>
                  <h1 className="text-xl font-bold">محرك المزامنة الهجينة وكشف التعارضات (Outbox / Inbox)</h1>
                  <p className="text-sm text-slate-500 mt-1">
                    لا يُطبّق Last-Write-Wins على السجلات الطبية أو المالية عند اختلاف رقم الإصدار (recordVersion).
                  </p>
                </div>
                <button
                  disabled={!isOnline}
                  onClick={handleSyncRun}
                  className="px-4 py-2 text-sm font-semibold rounded-lg bg-teal-700 text-white hover:bg-teal-800 disabled:opacity-50 whitespace-nowrap"
                >
                  تشغيل دورة المزامنة
                </button>
              </div>

              <div className="rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 divide-y divide-slate-100 dark:divide-slate-800">
                {outbox.map((item) => (
                  <div key={item.operationId} className="p-4 flex items-center justify-between gap-4">
                    <div>
                      <div className="text-sm font-semibold">{item.summary}</div>
                      <div className="text-xs text-slate-500 font-mono mt-1">
                        {item.entityType} · v{item.baseVersion} vs remote v{item.remoteVersion} · {item.status}
                        {item.conflictReason ? ` · ${item.conflictReason}` : ''}
                      </div>
                    </div>
                    {item.status === 'conflict' && hasRolePermission(role, 'sync.resolve_conflict') && (
                      <button
                        onClick={() => handleResolveConflict(item.operationId)}
                        className="px-3 py-1.5 text-xs font-medium rounded-lg bg-amber-600 text-white whitespace-nowrap"
                      >
                        مراجعة واعتماد بشري
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {activeNav === 'audit' && (
            <div className="space-y-4">
              <h1 className="text-xl font-bold">سجل التدقيق غير القابل للتعديل (Audit Logs)</h1>
              {!hasRolePermission(role, 'audit.read') ? (
                <div className="p-6 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-sm text-red-600">
                  ليست لديك صلاحية الاطلاع على سجل التدقيق بالدور الحالي.
                </div>
              ) : (
                <div className="rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 divide-y divide-slate-100 dark:divide-slate-800">
                  {auditLogs.map((log) => (
                    <div key={log.id} className="p-3.5 flex items-center justify-between text-sm">
                      <div>
                        <span className="font-mono font-semibold">{log.action}</span>
                        <span className="text-slate-500"> · {log.entity} · الدور: {log.actorRole}</span>
                      </div>
                      <span className="font-mono text-xs text-slate-500">{log.occurredAt}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {activeNav === 'architecture' && (
            <div className="space-y-6">
              <h1 className="text-xl font-bold">هيكلية مستودع Flutter + Dart + Firebase المنشأ فعلياً</h1>
              <div className="p-5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 space-y-3 text-sm leading-relaxed">
                <p>
                  تم إنشاء المستودع البرمجي الفعلي وفق تقنيات وثيقة SRS v1.1 داخل مجلد{' '}
                  <span className="font-mono text-xs">/cms/</span> دون استبدال أي تقنية معتمدة:
                </p>
                <ul className="list-disc pr-5 space-y-1.5 text-slate-700 dark:text-slate-300 font-mono text-xs">
                  <li>/cms/apps/clinic_app — تطبيق Flutter RTL (Material 3, Riverpod, GoRouter, 20 شاشة)</li>
                  <li>/cms/apps/local_server — خادم Dart المحلي (Shelf REST + WebSocket + Drift SQLite 18 جدول + Outbox Worker)</li>
                  <li>/cms/packages/core — محرك الصلاحيات (9 أدوار RBAC) وPHI-Safe Logger ومولد UUID</li>
                  <li>/cms/packages/shared — نماذج البيانات السريرية والمالية وواجهة LaboratoryIntegrationGateway</li>
                  <li>/cms/packages/design_system — ثيم Material 3 فاتح/داكن ومكونات التأكيد وحالة الشبكة</li>
                  <li>/cms/firebase — قواعد firestore.rules وstorage.rules والفهارس المركبة وCloud Functions (TypeScript)</li>
                  <li>/cms/docs — وثائق architecture.md وdatabase_design.md وsync_design.md وsecurity.md وdeployment.md</li>
                </ul>
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}
