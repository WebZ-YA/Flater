import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cms_core/core.dart';
import 'package:cms_design_system/design_system.dart';
import '../../auth/presentation/auth_provider.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  const ConsultationScreen({super.key});

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final _complaintCtrl = TextEditingController();
  final _bpCtrl = TextEditingController(text: '120/80');
  final _tempCtrl = TextEditingController(text: '37.0');
  final _diagnosisCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  bool _isFinalized = false;

  @override
  void dispose() {
    _complaintCtrl.dispose();
    _bpCtrl.dispose();
    _tempCtrl.dispose();
    _diagnosisCtrl.dispose();
    _planCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final canFinalize = session?.can(ClinicPermission.consultationFinalize) ?? false;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('الزيارة والمعاينة الطبية', style: Theme.of(context).textTheme.titleLarge),
            Text(_isFinalized ? 'الحالة: معتمدة ومقفلة نهائياً' : 'الحالة: مسودة قيد المعاينة'),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _complaintCtrl,
          enabled: !_isFinalized,
          decoration: const InputDecoration(labelText: 'الشكوى الرئيسية (Chief Complaint)'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _bpCtrl,
                enabled: !_isFinalized,
                decoration: const InputDecoration(labelText: 'ضغط الدم (mmHg)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _tempCtrl,
                enabled: !_isFinalized,
                decoration: const InputDecoration(labelText: 'درجة الحرارة (°C)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _diagnosisCtrl,
          enabled: !_isFinalized,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'التشخيص الطبي'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _planCtrl,
          enabled: !_isFinalized,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'خطة العلاج والملاحظات'),
        ),
        const SizedBox(height: 20),
        if (!_isFinalized && canFinalize)
          FilledButton.icon(
            onPressed: () async {
              final ok = await showCmsConfirmDialog(
                context,
                title: 'اعتماد وإغلاق الزيارة الطبية',
                message: 'بعد الاعتماد النهائي لن يمكن تعديل التشخيص بصمت وسيُسجل أي تعديل في سجل التدقيق.',
              );
              if (ok) {
                setState(() => _isFinalized = true);
                ref.read(pendingSyncCountProvider.notifier).state++;
              }
            },
            icon: const Icon(Icons.verified_outlined),
            label: const Text('اعتماد المعاينة وإغلاق الزيارة'),
          ),
      ],
    );
  }
}
