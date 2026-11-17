import 'package:flutter/material.dart';

class CmsConnectivityBanner extends StatelessWidget {
  const CmsConnectivityBanner({
    super.key,
    required this.isOnline,
    required this.pendingSyncCount,
    this.onOpenSyncCenter,
  });

  final bool isOnline;
  final int pendingSyncCount;
  final VoidCallback? onOpenSyncCenter;

  @override
  Widget build(BuildContext context) {
    if (isOnline && pendingSyncCount == 0) {
      return const SizedBox.shrink();
    }

    final bgColor = isOnline ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2);
    final fgColor = isOnline ? const Color(0xFF92400E) : const Color(0xFF991B1B);
    final message = isOnline
        ? 'يوجد $pendingSyncCount عمليات معلقة في انتظار المزامنة السحابية'
        : 'وضع العمل المحلي (Offline) — تستمر جميع العمليات عبر الخادم المحلي وسيتم الرفع عند عودة الإنترنت ($pendingSyncCount معلقة)';

    return Material(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(isOnline ? Icons.sync : Icons.cloud_off, color: fgColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: fgColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            if (onOpenSyncCenter != null)
              TextButton(
                onPressed: onOpenSyncCenter,
                child: Text('مركز المزامنة', style: TextStyle(color: fgColor)),
              ),
          ],
        ),
      ),
    );
  }
}

class CmsEmptyState extends StatelessWidget {
  const CmsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
