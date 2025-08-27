import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/work_orders_repository.dart';
import '../../models/work_order.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/priority_chip.dart';
import '../../core/widgets/responsive_constraints.dart';
import '../orders/work_order_details_page.dart';

class MySchedulePage extends ConsumerStatefulWidget {
  const MySchedulePage({super.key});

  @override
  ConsumerState<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends ConsumerState<MySchedulePage>
    with SingleTickerProviderStateMixin {
  final _repo = WorkOrdersRepository();
  late Future<List<WorkOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getAssignedToMe();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repo.getAssignedToMe();
    });
    await _future;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _effectiveDate(WorkOrder wo) {
    final status = (wo.status ?? '').toLowerCase();
    final due = wo.dueDate?.toLocal();
    final completed =
        status == 'completed' || status == 'done' || status == 'closed';
    final nextDate = wo.nextScheduledDate?.toLocal();
    if (due != null) return due;
    if (completed && nextDate != null) return nextDate; // for PM follow-up
    return null;
  }

  List<WorkOrder> _filterToday(List<WorkOrder> items) {
    final now = DateTime.now();
    final filtered =
        items.where((wo) {
            final d = _effectiveDate(wo);
            return d != null && _isSameDay(d, now);
          }).toList()
          ..sort((a, b) => _effectiveDate(a)!.compareTo(_effectiveDate(b)!));
    debugPrint(
      'Fetched work orders: \\n' +
          items
              .map(
                (wo) =>
                    'id: \\${wo.id}, due: \\${wo.dueDate}, next: \\${wo.nextScheduledDate}, status: \\${wo.status}',
              )
              .join(', '),
    );
    debugPrint('Filtered today: ' + filtered.map((wo) => wo.id).join(', '));
    return filtered;
  }

  List<WorkOrder> _filterWeek(List<WorkOrder> items) {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    return items.where((wo) {
        final d = _effectiveDate(wo);
        return d != null &&
            d.isAfter(now.subtract(const Duration(days: 1))) &&
            d.isBefore(end);
      }).toList()
      ..sort((a, b) => _effectiveDate(a)!.compareTo(_effectiveDate(b)!));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Schedule'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Today'),
              Tab(text: 'Week'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<WorkOrder>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = List<WorkOrder>.of(snapshot.data ?? const []);
              return TabBarView(
                children: [
                  _ScheduleList(items: _filterToday(items)),
                  _ScheduleList(items: _filterWeek(items)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final List<WorkOrder> items;
  const _ScheduleList({required this.items});

  String _titleCase(String input) {
    final s = input.trim();
    if (s.isEmpty) return input;
    return s
        .split(RegExp(r'\s+'))
        .map(
          (w) => w.isEmpty
              ? w
              : (w[0].toUpperCase() + w.substring(1).toLowerCase()),
        )
        .join(' ');
  }

  String _fmtShort(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${d.month}/${two(d.year % 100)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('No scheduled orders')),
        ],
      );
    }
    return ResponsiveConstraints(
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final wo = items[i];
          final effective = wo.dueDate ?? wo.nextScheduledDate ?? wo.createdAt;
          return ListTile(
            key: ValueKey(wo.id),
            leading: const Icon(Icons.schedule),
            title: Text(
              _titleCase((wo.title ?? 'Untitled')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if ((wo.status ?? '').isNotEmpty) StatusChip(wo.status!),
                PriorityChip(wo.priority),
                if (effective != null)
                  Text(
                    _fmtShort(effective.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkOrderDetailsPage(id: wo.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
