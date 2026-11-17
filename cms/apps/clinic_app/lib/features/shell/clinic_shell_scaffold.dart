import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cms_core/core.dart';
import 'package:cms_design_system/design_system.dart';
import '../../main.dart';
import '../auth/presentation/auth_provider.dart';

class ClinicShellScaffold extends ConsumerWidget {
  const ClinicShellScaffold({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final pendingSync = ref.watch(pendingSyncCountProvider);

    final navItems = <(String path, String label, IconData icon, ClinicPermission? perm)>[
      ('/dashboard', 'لوحة التحكم', Icons.dashboard_outlined, null),
      ('/patients', 'المرضى', Icons.people_outline, ClinicPermission.patientsRead),
      ('/appointments', 'المواعيد', Icons.calendar_month_outlined, ClinicPermission.appointmentsManage),
      ('/queue', 'طابور الانتظار', Icons.confirmation_number_outlined, ClinicPermission.queueManage),
      ('/consultation', 'المعاينة الطبية', Icons.medical_services_outlined, ClinicPermission.consultationWrite),
      ('/lab-orders', 'طلبات الفحوصات', Icons.biotech_outlined, ClinicPermission.labOrdersCreate),
      ('/lab-results', 'نتائج المختبر', Icons.fact_check_outlined, ClinicPermission.labResultsUpload),
      ('/prescriptions', 'الوصفات الطبية', Icons.medication_outlined, ClinicPermission.prescriptionsWrite),
      ('/archive', 'الأرشيف الطبي', Icons.folder_copy_outlined, ClinicPermission.archiveManage),
      ('/invoices', 'الفواتير والصندوق', Icons.receipt_long_outlined, ClinicPermission.invoicesWrite),
      ('/reports', 'التقارير', Icons.bar_chart_outlined, ClinicPermission.reportsClinical),
      ('/sync-center', 'حالة المزامنة', Icons.sync_outlined, null),
      ('/users', 'المستخدمون', Icons.admin_panel_settings_outlined, ClinicPermission.usersManage),
      ('/audit-logs', 'سجل التدقيق', Icons.policy_outlined, ClinicPermission.auditRead),
      ('/settings', 'الإعدادات', Icons.settings_outlined, null),
    ].where((item) {
      if (item.$4 == null || session == null) return true;
      return session.can(item.$4!);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام إدارة العيادات الطبية (CMS)'),
        actions: [
          IconButton(
            tooltip: 'شاشة انتظار المرضى',
            onPressed: () => context.push('/waiting-display'),
            icon: const Icon(Icons.tv_outlined),
          ),
          IconButton(
            tooltip: 'تبديل المظهر الفاتح/الداكن',
            onPressed: () {
              final current = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
            },
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authSessionProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          CmsConnectivityBanner(
            isOnline: isOnline,
            pendingSyncCount: pendingSync,
            onOpenSyncCenter: () => context.go('/sync-center'),
          ),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  extended: MediaQuery.sizeOf(context).width >= 1100,
                  selectedIndex: navItems.indexWhere((e) => e.$1 == currentPath).clamp(0, navItems.length - 1),
                  onDestinationSelected: (idx) => context.go(navItems[idx].$1),
                  destinations: navItems
                      .map((e) => NavigationRailDestination(
                            icon: Icon(e.$3),
                            label: Text(e.$2),
                          ))
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
