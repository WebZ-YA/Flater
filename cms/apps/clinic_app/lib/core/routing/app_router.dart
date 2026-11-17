import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cms_core/core.dart';

import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/patients/presentation/patients_screen.dart';
import '../../features/queue/presentation/queue_screens.dart';
import '../../features/consultations/presentation/consultation_screen.dart';
import '../../features/labs/presentation/labs_screen.dart';
import '../../features/prescriptions/presentation/prescriptions_screen.dart';
import '../../features/billing/presentation/billing_screen.dart';
import '../../features/sync_center/presentation/sync_center_screen.dart';
import '../../features/audit_logs/presentation/audit_logs_screen.dart';
import '../../features/shell/clinic_shell_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.uri.path;
      if (session == null) {
        return (path == '/login' || path == '/splash') ? null : '/login';
      }
      if (path == '/login' || path == '/splash') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashBootstrapScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/waiting-display',
        builder: (_, __) => const WaitingRoomDisplayScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ClinicShellScaffold(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/patients', builder: (_, __) => const PatientsScreen()),
          GoRoute(path: '/appointments', builder: (_, __) => const AppointmentsPlaceholderView()),
          GoRoute(path: '/queue', builder: (_, __) => const QueueManagementScreen()),
          GoRoute(path: '/consultation', builder: (_, __) => const ConsultationScreen()),
          GoRoute(path: '/lab-orders', builder: (_, __) => const LabOrdersAndResultsScreen(initialTab: 0)),
          GoRoute(path: '/lab-results', builder: (_, __) => const LabOrdersAndResultsScreen(initialTab: 1)),
          GoRoute(path: '/prescriptions', builder: (_, __) => const PrescriptionsScreen()),
          GoRoute(path: '/archive', builder: (_, __) => const MedicalArchiveScreen()),
          GoRoute(path: '/invoices', builder: (_, __) => const BillingScreen(initialTab: 0)),
          GoRoute(path: '/payments', builder: (_, __) => const BillingScreen(initialTab: 1)),
          GoRoute(path: '/expenses', builder: (_, __) => const BillingScreen(initialTab: 2)),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/users', builder: (_, __) => const UsersAndPermissionsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const ClinicSettingsScreen()),
          GoRoute(path: '/sync-center', builder: (_, __) => const SyncCenterScreen()),
          GoRoute(
            path: '/audit-logs',
            redirect: (_, __) {
              if (session != null && !session.can(ClinicPermission.auditRead)) {
                return '/dashboard';
              }
              return null;
            },
            builder: (_, __) => const AuditLogsScreen(),
          ),
        ],
      ),
    ],
  );
});

class SplashBootstrapScreen extends ConsumerWidget {
  const SplashBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future.microtask(() {
      if (context.mounted) context.go('/login');
    });
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جارٍ تهيئة نظام إدارة العيادات الطبية...'),
          ],
        ),
      ),
    );
  }
}
