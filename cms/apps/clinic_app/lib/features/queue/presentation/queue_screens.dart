import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cms_core/core.dart';
import 'package:cms_shared/shared.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../patients/presentation/patients_screen.dart';

final queueTicketsProvider = StateProvider<List<QueueTicketRecord>>((ref) => const []);

class QueueManagementScreen extends ConsumerWidget {
  const QueueManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(queueTicketsProvider);
    final patients = ref.watch(patientsProvider);
    final session = ref.watch(authSessionProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('إدارة طابور الانتظار اليومي', style: Theme.of(context).textTheme.titleLarge),
              FilledButton.icon(
                onPressed: patients.isEmpty || session == null
                    ? null
                    : () {
                        final p = patients.first;
                        final now = DateTime.now().toUtc();
                        final nextNum = tickets.length + 1;
                        final newTicket = QueueTicketRecord(
                          id: IdGenerator.newUuid(),
                          tenantId: session.tenantId,
                          clinicId: session.tenantId,
                          branchId: 'main-branch',
                          createdAt: now,
                          updatedAt: now,
                          createdBy: session.uid,
                          updatedBy: session.uid,
                          queueDate: now.toIso8601String().substring(0, 10),
                          ticketNumber: nextNum,
                          patientId: p.id,
                          patientName: p.fullName,
                          doctorId: session.uid,
                          visitType: 'first_consultation',
                          status: 'waiting',
                        );
                        ref.read(queueTicketsProvider.notifier).state = [...tickets, newTicket];
                      },
                icon: const Icon(Icons.confirmation_number),
                label: const Text('إصدار رقم انتظار للمريض الأول'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: tickets.length,
              itemBuilder: (ctx, i) {
                final t = tickets[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(t.formattedTicket)),
                    title: Text(t.patientName),
                    subtitle: Text('الحالة: ${t.status} · التخطي: ${t.skipCount}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            ref.read(queueTicketsProvider.notifier).state = [
                              for (final item in tickets)
                                if (item.id == t.id)
                                  QueueTicketRecord(
                                    id: item.id,
                                    tenantId: item.tenantId,
                                    clinicId: item.clinicId,
                                    branchId: item.branchId,
                                    createdAt: item.createdAt,
                                    updatedAt: DateTime.now().toUtc(),
                                    createdBy: item.createdBy,
                                    updatedBy: session?.uid ?? item.updatedBy,
                                    queueDate: item.queueDate,
                                    ticketNumber: item.ticketNumber,
                                    patientId: item.patientId,
                                    patientName: item.patientName,
                                    doctorId: item.doctorId,
                                    visitType: item.visitType,
                                    status: 'called',
                                    calledAt: DateTime.now().toUtc(),
                                  )
                                else
                                  item,
                            ];
                          },
                          child: const Text('استدعاء'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WaitingRoomDisplayScreen extends ConsumerWidget {
  const WaitingRoomDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(queueTicketsProvider);
    final called = tickets.where((t) => t.status == 'called').toList();
    final waiting = tickets.where((t) => t.status == 'waiting').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('شاشة انتظار المرضى')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Row(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('الرقم المستدعى حالياً', style: Theme.of(context).textTheme.headlineSmall),
                      const Divider(),
                      Expanded(
                        child: Center(
                          child: Text(
                            called.isEmpty ? '---' : called.last.formattedTicket,
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('قائمة الانتظار (${waiting.length})', style: Theme.of(context).textTheme.headlineSmall),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          children: waiting
                              .map((t) => ListTile(
                                    title: Text(t.formattedTicket, style: Theme.of(context).textTheme.titleLarge),
                                    subtitle: Text(t.patientName),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppointmentsPlaceholderView extends StatelessWidget {
  const AppointmentsPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تقويم المواعيد (يومي / أسبوعي / شهري) ومنع تعارض المواعيد'),
          SizedBox(height: 12),
          Text('مرتبط بجدول local_appointments و/tenants/{tenantId}/appointments.'),
        ],
      ),
    );
  }
}
