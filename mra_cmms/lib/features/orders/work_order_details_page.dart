import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mra_cmms/models/work_order.dart';
import 'package:mra_cmms/repositories/assets_repository.dart';
import 'package:mra_cmms/repositories/locations_repository.dart';

// ---- Section Widgets ----
class _HeaderSection extends StatelessWidget {
  final WorkOrder wo;
  final String id;
  const _HeaderSection({required this.wo, required this.id});

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime? d) =>
      d == null ? '-' : '${_two(d.day)}/${d.month}/${_two(d.year % 100)}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wo.title ?? 'Untitled',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${id.split('-').first.toUpperCase()}',
            style: textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if ((wo.status ?? '').isNotEmpty) Chip(label: Text(wo.status!)),
              Chip(label: Text('Priority')), // Placeholder
              Chip(
                label: Text(
                  'Due: ${_fmtDate(wo.dueDate)}',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyInfoSection extends StatelessWidget {
  final String created;
  final String due;
  final String requesterName;
  final String? assigneeName;
  const _KeyInfoSection({
    required this.created,
    required this.due,
    required this.requesterName,
    this.assigneeName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _InfoRow(label: 'Created', value: created),
          _InfoRow(label: 'Due Date', value: due),
          _InfoRow(label: 'Requested By', value: requesterName),
          if (assigneeName != null)
            _InfoRow(label: 'Assigned To', value: assigneeName!),
        ],
      ),
    );
  }
}

class _AssetLocationSection extends StatelessWidget {
  final AssetInfo? asset;
  final LocationInfo? location;
  final VoidCallback? onTapAsset;
  final VoidCallback? onTapLocation;
  const _AssetLocationSection({
    required this.asset,
    required this.location,
    this.onTapAsset,
    this.onTapLocation,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Column(
        children: [
          ListTile(
            key: ValueKey('asset-${asset?.id ?? ''}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Asset',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(((asset?.assetId ?? '-')).toUpperCase()),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTapAsset,
          ),
          const Divider(height: 1),
          ListTile(
            key: ValueKey('location-${location?.locationId ?? ''}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Location',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(((location?.locationId ?? '-')).toUpperCase()),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTapLocation,
          ),
        ],
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final String text;
  const _DescriptionSection({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  final List<String> attachmentUrls;
  final Future<void> Function(dynamic) onPick;
  const _AttachmentsSection({
    required this.attachmentUrls,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const ListTile(title: Text('Attachments')),
          if (attachmentUrls.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No attachments'),
            ),
          // Add attachment preview widgets here
        ],
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No activity yet',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _CompletionSection extends StatelessWidget {
  final List<_TaskItem> tasks;
  final bool isLocked;
  final bool isDisabled;
  final String status;
  final bool isAdmin;
  final void Function(int index, bool value)? onToggleTask;
  final Future<void> Function()? onSubmitReview;

  const _CompletionSection({
    required this.tasks,
    required this.isLocked,
    required this.isDisabled,
    required this.status,
    required this.isAdmin,
    this.onToggleTask,
    this.onSubmitReview,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(tasks.length, (i) {
              final t = tasks[i];
              return CheckboxListTile(
                value: t.done,
                onChanged: isLocked || onToggleTask == null
                    ? null
                    : (v) => onToggleTask!(i, v ?? false),
                title: Text(t.title),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            }),
            const SizedBox(height: 12),
            if (onSubmitReview != null)
              FilledButton.icon(
                icon: const Icon(Icons.rate_review),
                label: const Text('Submit for Review'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: onSubmitReview,
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskItem {
  final String title;
  bool done = false;
  _TaskItem(this.title);
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class WorkOrderDetailsPage extends ConsumerStatefulWidget {
  final String id;
  const WorkOrderDetailsPage({super.key, required this.id});

  @override
  ConsumerState<WorkOrderDetailsPage> createState() =>
      _WorkOrderDetailsPageState();
}

class _WorkOrderDetailsPageState extends ConsumerState<WorkOrderDetailsPage> {
  @override
  Widget build(BuildContext context) {
    // Example: Use the fields and section widgets to build the full UI
    return Scaffold(
      appBar: AppBar(title: const Text('Work Order Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Example header section
          _HeaderSection(
            wo: WorkOrder(id: widget.id),
            id: widget.id,
          ),
          const SizedBox(height: 16),
          // Example key info section
          _KeyInfoSection(
            created: '2025-08-27',
            due: '2025-09-01',
            requesterName: 'John Doe',
            assigneeName: 'Jane Smith',
          ),
          const SizedBox(height: 16),
          // Example asset/location section
          _AssetLocationSection(
            asset: null,
            location: null,
            onTapAsset: null,
            onTapLocation: null,
          ),
          const SizedBox(height: 16),
          // Example description section
          _DescriptionSection(text: 'Work order description goes here.'),
          const SizedBox(height: 16),
          // Example attachments section
          _AttachmentsSection(attachmentUrls: const [], onPick: (_) async {}),
          const SizedBox(height: 16),
          // Example activity section
          const _ActivitySection(),
          const SizedBox(height: 16),
          // Example completion section
          _CompletionSection(
            tasks: [
              _TaskItem('Verify issue on site'),
              _TaskItem('Perform repair/maintenance'),
              _TaskItem('Test and validate fix'),
              _TaskItem('Attach photos/evidence'),
              _TaskItem('Add completion notes'),
            ],
            isLocked: false,
            isDisabled: false,
            status: 'open',
            isAdmin: false,
            onToggleTask: (i, v) {},
            onSubmitReview: () async {},
          ),
        ],
      ),
    );
  }
}
