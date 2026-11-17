import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';

class SyncCenterScreen extends ConsumerWidget {
  const SyncCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pending = ref.watch(pendingSyncCountProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مركز المزامنة وحل التعارضات', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('محاكاة حالة الاتصال بالإنترنت'),
              subtitle: Text(isOnline ? 'متصل — المزامنة التلقائية مفعلة' : 'غير متصل — العمل عبر الخادم المحلي'),
              value: isOnline,
              onChanged: (v) => ref.read(isOnlineProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: 12),
          Text('العمليات المعلقة في Outbox: $pending'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isOnline ? () => ref.read(pendingSyncCountProvider.notifier).state = 0 : null,
            icon: const Icon(Icons.sync),
            label: const Text('تشغيل دورة المزامنة الآن'),
          ),
        ],
      ),
    );
  }
}
