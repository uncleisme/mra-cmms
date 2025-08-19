import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mra_cmms/models/work_order.dart';
import 'package:mra_cmms/repositories/work_orders_repository.dart';
import 'package:mra_cmms/repositories/attachments_repository.dart';
import 'package:mra_cmms/core/widgets/section_card.dart';
import 'package:mra_cmms/core/widgets/status_chip.dart';
import 'package:mra_cmms/core/widgets/priority_chip.dart';
import 'package:image_picker/image_picker.dart';

class WorkOrderDetailsPage extends ConsumerStatefulWidget {
  final String id;
  const WorkOrderDetailsPage({super.key, required this.id});

  @override
  ConsumerState<WorkOrderDetailsPage> createState() => _WorkOrderDetailsPageState();
}

class _WorkOrderDetailsPageState extends ConsumerState<WorkOrderDetailsPage> {
  final repo = WorkOrdersRepository();
  final attachmentsRepo = AttachmentsRepository();
  late Future<WorkOrder?> _future;
  late List<_TaskItem> _tasks;
  List<String> _attachmentUrls = const [];

  @override
  void initState() {
    super.initState();
    _future = repo.getById(widget.id);
    _tasks = [
      _TaskItem('Verify issue on site'),
      _TaskItem('Perform repair/maintenance'),
      _TaskItem('Test and validate fix'),
      _TaskItem('Attach photos/evidence'),
      _TaskItem('Add completion notes'),
    ];
    _loadAttachments();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = repo.getById(widget.id);
    });
    await _future;
    await _loadAttachments();
  }

  Future<void> _loadAttachments() async {
    try {
      final urls = await attachmentsRepo.listUrls(widget.id);
      if (!mounted) return;
      setState(() => _attachmentUrls = urls);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load attachments: $e')));
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 2048);
      if (xfile == null) return;
      final file = File(xfile.path);
      await attachmentsRepo.upload(widget.id, file, filename: xfile.name);
      await _loadAttachments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Order'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<WorkOrder?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final wo = snap.data;
            if (wo == null) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('Work order not found')),
                ],
              );
            }

            String two(int n) => n.toString().padLeft(2, '0');
            String fmtDate(DateTime? d) => d == null
                ? '-'
                : '${d.year}-${two(d.month)}-${two(d.day)}';

            final status = (wo.status ?? '').toLowerCase();
            // Lock checklist for Done and Review (and other final states)
            final isLocked =
                status == 'completed' || status == 'done' || status == 'closed' || status == 'review' || status.contains('review');
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Header section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wo.title ?? 'Untitled',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if ((wo.status ?? '').isNotEmpty) StatusChip(wo.status!),
                          PriorityChip(wo.priority),
                          Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Due: '),
                                Text(fmtDate(wo.dueDate)),
                              ],
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Key info
                SectionCard(
                  title: 'Key info',
                  child: Column(
                    children: [
                      _InfoRow(label: 'Status', value: (wo.status ?? '-')),
                      _InfoRow(label: 'Priority', value: (wo.priority ?? '-')),
                      _InfoRow(label: 'Due date', value: fmtDate(wo.dueDate)),
                      _InfoRow(label: 'Created', value: fmtDate(wo.createdDate ?? wo.createdAt)),
                      _InfoRow(label: 'Assigned to', value: wo.assignedTo ?? '-'),
                      _InfoRow(label: 'Requested by', value: wo.requestedBy ?? '-'),
                      _InfoRow(label: 'Asset', value: wo.assetId ?? '-'),
                      _InfoRow(label: 'Location', value: wo.locationId ?? '-'),
                    ],
                  ),
                ),

                // Description
                if ((wo.description ?? '').isNotEmpty)
                  SectionCard(
                    title: 'Description',
                    child: Text(
                      wo.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),

                // Placeholders for future sections
                SectionCard(
                  title: 'Attachments',
                  actions: [
                    IconButton(
                      tooltip: 'Add from camera',
                      onPressed: () => _pickAndUpload(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    IconButton(
                      tooltip: 'Add from gallery',
                      onPressed: () => _pickAndUpload(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                    ),
                  ],
                  child: _attachmentUrls.isEmpty
                      ? Text('No attachments', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                          itemCount: _attachmentUrls.length,
                          itemBuilder: (context, index) {
                            final url = _attachmentUrls[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
                                  ),
                                ),
                                child: Image.network(url, fit: BoxFit.cover),
                              ),
                            );
                          },
                        ),
                ),
                SectionCard(
                  title: 'Activity',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No activity yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),

                // Completion checklist and action
                SectionCard(
                  title: 'Completion',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLocked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('This job is completed. Checklist is read-only.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                      ..._tasks.map((t) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(t.title),
                            value: t.done,
                            onChanged: isLocked ? null : (v) => setState(() => t.done = v ?? false),
                          )),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: (!isLocked && _tasks.every((t) => t.done))
                            ? () async {
                                // TODO: call repository to mark as completed
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job marked as completed')));
                              }
                            : null,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Complete job'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaskItem {
  final String title;
  bool done;
  _TaskItem(this.title, {this.done = false});
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
          SizedBox(width: 120, child: Text(label, style: textTheme.bodyMedium?.copyWith(color: color))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
