import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuditLogsScreen extends ConsumerWidget {
  const AuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('سجل التدقيق غير القابل للتعديل (Audit Logs)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('يعرض جميع العمليات الحساسة (المستخدم، الدور، الوقت، الجهاز، الكيان المتأثر، والقيم السابقة واللاحقة).'),
        ],
      ),
    );
  }
}
