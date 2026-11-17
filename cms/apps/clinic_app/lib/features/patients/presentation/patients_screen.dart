import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cms_core/core.dart';
import 'package:cms_shared/shared.dart';
import 'package:cms_design_system/design_system.dart';
import '../../auth/presentation/auth_provider.dart';

class PatientsNotifier extends StateNotifier<List<PatientRecord>> {
  PatientsNotifier(this._ref) : super(const []);

  final Ref _ref;

  Future<void> registerPatient({
    required String fullName,
    required String phone,
    required String gender,
    String address = '',
    List<String> allergies = const [],
    List<String> chronicConditions = const [],
    bool confirmDuplicateOverride = false,
  }) async {
    final session = _ref.read(authSessionProvider);
    if (session == null || !session.can(ClinicPermission.patientsWrite)) {
      throw const PermissionFailure();
    }

    final normalizedPhone = IdGenerator.normalizePhone(phone);
    final duplicate = state.any((p) => p.normalizedPhone == normalizedPhone && !p.archived);
    if (duplicate && !confirmDuplicateOverride) {
      throw const DuplicateRecordFailure(
        'DUPLICATE_PATIENT',
        'يوجد مريض مسجل مسبقاً بنفس رقم الهاتف. يرجى التحقق لمنع تكرار الملف الطبي.',
      );
    }

    final now = DateTime.now().toUtc();
    final patient = PatientRecord(
      id: IdGenerator.newUuid(),
      tenantId: session.tenantId,
      clinicId: session.tenantId,
      branchId: 'main-branch',
      createdAt: now,
      updatedAt: now,
      createdBy: session.uid,
      updatedBy: session.uid,
      medicalNumber: IdGenerator.formatSequentialNumber('PAT', state.length + 1),
      fullName: fullName.trim(),
      gender: gender,
      phone: phone.trim(),
      normalizedPhone: normalizedPhone,
      address: address.trim(),
      allergies: allergies,
      chronicConditions: chronicConditions,
    );

    state = [patient, ...state];
    _ref.read(pendingSyncCountProvider.notifier).state++;
  }

  void archivePatient(String patientId) {
    final session = _ref.read(authSessionProvider);
    if (session == null || !session.can(ClinicPermission.patientsArchive)) {
      throw const PermissionFailure();
    }
    state = [
      for (final p in state)
        if (p.id == patientId)
          PatientRecord(
            id: p.id,
            tenantId: p.tenantId,
            clinicId: p.clinicId,
            branchId: p.branchId,
            createdAt: p.createdAt,
            updatedAt: DateTime.now().toUtc(),
            createdBy: p.createdBy,
            updatedBy: session.uid,
            recordVersion: p.recordVersion + 1,
            medicalNumber: p.medicalNumber,
            fullName: p.fullName,
            gender: p.gender,
            phone: p.phone,
            normalizedPhone: p.normalizedPhone,
            allergies: p.allergies,
            chronicConditions: p.chronicConditions,
            archived: true,
          )
        else
          p,
    ];
  }
}

final patientsProvider = StateNotifierProvider<PatientsNotifier, List<PatientRecord>>((ref) {
  return PatientsNotifier(ref);
});

class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final patients = ref
        .watch(patientsProvider)
        .where((p) => !p.archived)
        .where((p) =>
            _search.isEmpty ||
            p.fullName.contains(_search) ||
            p.phone.contains(_search) ||
            p.medicalNumber.contains(_search))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'بحث بالاسم أو الهاتف أو الرقم الطبي (PAT-...)',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openAddPatientDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('تسجيل مريض جديد'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: patients.isEmpty
                ? CmsEmptyState(
                    icon: Icons.people_outline,
                    title: 'لا توجد سجلات مرضى مطابقة',
                    subtitle: 'ابدأ بتسجيل مريض جديد لإصدار رقم ملف طبي دائم وبطاقة QR.',
                    actionLabel: 'تسجيل مريض',
                    onAction: () => _openAddPatientDialog(context),
                  )
                : ListView.separated(
                    itemCount: patients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final p = patients[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(p.fullName.characters.first)),
                          title: Text('${p.fullName} — ${p.medicalNumber}'),
                          subtitle: Text('الهاتف: ${p.phone} · الحساسية: ${p.allergies.isEmpty ? "لا يوجد" : p.allergies.join("، ")}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'بطاقة المريض QR',
                                icon: const Icon(Icons.qr_code),
                                onPressed: () => _showPatientQrCard(context, p),
                              ),
                              IconButton(
                                tooltip: 'أرشفة السجل',
                                icon: const Icon(Icons.archive_outlined),
                                onPressed: () async {
                                  final confirmed = await showCmsConfirmDialog(
                                    context,
                                    title: 'أرشفة ملف المريض',
                                    message: 'سيتم أرشفة الملف دون حذف التاريخ الطبي أو الزيارات السابقة.',
                                  );
                                  if (confirmed) {
                                    ref.read(patientsProvider.notifier).archivePatient(p.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddPatientDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final allergyCtrl = TextEditingController();
    String gender = 'male';

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل مريض جديد'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: gender,
                decoration: const InputDecoration(labelText: 'الجنس'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('ذكر')),
                  DropdownMenuItem(value: 'female', child: Text('أنثى')),
                ],
                onChanged: (v) => gender = v ?? 'male',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: allergyCtrl,
                decoration: const InputDecoration(labelText: 'الحساسية الدوائية (مفصولة بفاصلة)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(patientsProvider.notifier).registerPatient(
                      fullName: nameCtrl.text,
                      phone: phoneCtrl.text,
                      gender: gender,
                      allergies: allergyCtrl.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(),
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();
              } on CmsFailure catch (f) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(f.arabicMessage)));
                }
              }
            },
            child: const Text('حفظ الملف الطبي'),
          ),
        ],
      ),
    );
  }

  void _showPatientQrCard(BuildContext context, PatientRecord p) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('بطاقة المريض — ${p.medicalNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: p.nonSensitiveQrPayload, size: 180),
            const SizedBox(height: 8),
            Text(p.fullName),
            Text('رمز QR يحتوي الرقم الطبي فقط دون أي معلومات طبية حساسة',
                style: Theme.of(ctx).textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
