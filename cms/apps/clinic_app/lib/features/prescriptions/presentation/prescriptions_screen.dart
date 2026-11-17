import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrescriptionsScreen extends ConsumerWidget {
  const PrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الوصفات الطبية ودليل الأدوية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('إصدار الوصفة بالاسم العلمي والتجاري والتركيز والجرعة والتكرار والمدة، مع دعم الطباعة وحفظ السجل.'),
        ],
      ),
    );
  }
}

class MedicalArchiveScreen extends ConsumerWidget {
  const MedicalArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الأرشيف الطبي والملفات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('تصنيف الوثائق الطبية وإصداراتها والاحتفاظ بالنسخ الأصلية في Firebase Storage أو الخادم المحلي.'),
        ],
      ),
    );
  }
}
