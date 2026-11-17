import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cms_core/core.dart';
import 'package:cms_shared/shared.dart';
import '../../auth/presentation/auth_provider.dart';

class LabOrdersAndResultsScreen extends ConsumerStatefulWidget {
  const LabOrdersAndResultsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<LabOrdersAndResultsScreen> createState() => _LabOrdersAndResultsScreenState();
}

class _LabOrdersAndResultsScreenState extends ConsumerState<LabOrdersAndResultsScreen> {
  final List<Map<String, dynamic>> _orders = [];
  final _gateway = const ManualLaboratoryGateway('manual-lab-default');

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final canOrder = session?.can(ClinicPermission.labOrdersCreate) ?? false;
    final canApprove = session?.can(ClinicPermission.labResultsApprove) ?? false;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'طلبات الفحوصات الخارجية'),
              Tab(text: 'النتائج ومراجعة الطبيب'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الطلبات الصادرة للمختبرات الخارجية',
                              style: Theme.of(context).textTheme.titleMedium),
                          if (canOrder)
                            FilledButton.icon(
                              onPressed: () async {
                                final orderNum = IdGenerator.formatSequentialNumber(
                                    'LAB', _orders.length + 1);
                                final receipt = await _gateway.submitLabOrder(
                                  tenantId: session!.tenantId,
                                  orderId: IdGenerator.newUuid(),
                                  orderNumber: orderNum,
                                  patientMedicalNumber: 'PAT-000001',
                                  testCodes: ['CBC', 'FBS'],
                                );
                                setState(() {
                                  _orders.add({
                                    'orderNumber': orderNum,
                                    'tests': 'CBC, FBS',
                                    'reviewStatus': 'pending_review',
                                    'note': receipt.message,
                                  });
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('إنشاء طلب فحص مخبري'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _orders.length,
                          itemBuilder: (_, i) {
                            final o = _orders[i];
                            return Card(
                              child: ListTile(
                                title: Text('طلب ${o['orderNumber']} — ${o['tests']}'),
                                subtitle: Text('${o['note']}'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    children: [
                      Text('اعتماد نتائج المختبر (يتطلب مراجعة بشرية من الطبيب)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ..._orders.map((o) => Card(
                            child: ListTile(
                              title: Text('نتيجة الطلب ${o['orderNumber']}'),
                              subtitle: Text('حالة الاعتماد: ${o['reviewStatus']}'),
                              trailing: canApprove && o['reviewStatus'] == 'pending_review'
                                  ? FilledButton(
                                      onPressed: () => setState(() => o['reviewStatus'] = 'approved'),
                                      child: const Text('اعتماد الطبيب'),
                                    )
                                  : null,
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
