import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cms_core/core.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  double _clinicServices = 5000;
  double _externalLabFee = 3500;
  bool _hasLabContract = false;

  @override
  Widget build(BuildContext context) {
    // SRS §8.10: Separate external lab fees unless contractual agreement exists
    final clinicRevenue = _hasLabContract ? (_clinicServices + _externalLabFee) : _clinicServices;
    final labPassThrough = _hasLabContract ? 0.0 : _externalLabFee;
    final grandTotal = clinicRevenue + labPassThrough;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text('الفواتير والمدفوعات والصندوق اليومي', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('احتساب الفصل المالي لرسوم المختبر الخارجي',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('توجد اتفاقية مالية تعاقدية مع المختبر الخارجي'),
                    value: _hasLabContract,
                    onChanged: (v) => setState(() => _hasLabContract = v),
                  ),
                  const Divider(),
                  Text('إيراد العيادة الصافي: ${CurrencyFormatter.format(clinicRevenue)}'),
                  Text('رسوم المختبر الخارجي المفصولة (Pass-Through): ${CurrencyFormatter.format(labPassThrough)}'),
                  const SizedBox(height: 8),
                  Text(
                    'إجمالي الفاتورة المستحق: ${CurrencyFormatter.format(grandTotal)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text('التقارير الطبية والإدارية والمالية وتقارير أداء الموظفين'),
    );
  }
}

class UsersAndPermissionsScreen extends StatelessWidget {
  const UsersAndPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          Text('الأدوار والصلاحيات المعتمدة (RBAC)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...ClinicRole.values.map(
            (role) => Card(
              child: ListTile(
                title: Text(role.arabicLabel),
                subtitle: Text('الكود البرمجي: ${role.code} · عدد الأذونات: ${RbacPolicyEngine.defaultRoleMatrix[role]?.length ?? 0}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClinicSettingsScreen extends StatelessWidget {
  const ClinicSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text('إعدادات العيادة والفروع والعملة الافتراضية (YER) وخادم الشبكة المحلية'),
    );
  }
}
