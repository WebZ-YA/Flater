import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cms_core/core.dart';
import '../../auth/presentation/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final pendingSync = ref.watch(pendingSyncCountProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'مرحباً ${session?.displayName ?? ''} — ${session?.role.arabicLabel ?? ''}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _KpiTile(label: 'حالة الشبكة والمزامنة', value: isOnline ? 'متصل بالسحابة' : 'محلي (Offline)'),
            _KpiTile(label: 'عمليات المزامنة المعلقة', value: '$pendingSync عملية'),
            _KpiTile(label: 'العملة الافتراضية', value: CurrencyFormatter.format(0, currencyCode: 'YER')),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الوصول السريع للعمليات', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/patients'),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('تسجيل مريض'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/queue'),
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: const Text('إصدار رقم انتظار'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/consultation'),
                      icon: const Icon(Icons.medical_services_outlined),
                      label: const Text('فتح معاينة طبية'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/invoices'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('إصدار فاتورة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
