import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mra_cmms/models/work_order.dart';
import 'package:mra_cmms/repositories/work_orders_repository.dart';
import 'package:mra_cmms/repositories/assets_repository.dart';
import 'package:mra_cmms/repositories/locations_repository.dart';
import 'package:mra_cmms/features/assets/asset_details_page.dart';
import 'package:mra_cmms/features/locations/location_details_page.dart';
import 'package:mra_cmms/repositories/attachments_repository.dart';
import 'package:mra_cmms/repositories/profiles_repository.dart';
import 'package:mra_cmms/models/profile.dart';
import 'package:mra_cmms/core/widgets/section_card.dart';
import 'package:mra_cmms/core/widgets/status_chip.dart';
import 'package:mra_cmms/core/widgets/priority_chip.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mra_cmms/core/widgets/responsive_constraints.dart';

class WorkOrderDetailsPage extends ConsumerStatefulWidget {
  final String id;
  const WorkOrderDetailsPage({super.key, required this.id});

  @override
  ConsumerState<WorkOrderDetailsPage> createState() => _WorkOrderDetailsPageState();
}

class _WorkOrderDetailsPageState extends ConsumerState<WorkOrderDetailsPage> {
  final repo = WorkOrdersRepository();
  final assetsRepo = AssetsRepository();
  final locationsRepo = LocationsRepository();
  final attachmentsRepo = AttachmentsRepository();
  final profilesRepo = ProfilesRepository();
  late Future<WorkOrder?> _future;
  late List<_TaskItem> _tasks;
  List<String> _attachmentUrls = const [];
  AssetInfo? _asset;
  LocationInfo? _location;
  Profile? _requester;
  String? _assetIdLoaded;
  String? _locationIdLoaded;
  String? _requesterIdLoaded;

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

  Future<void> _ensureRefsLoaded(WorkOrder wo) async {
    // Asset: work_orders.asset_id stores assets.id (UUID). Fetch by id, display asset_id.
    final aid = wo.assetId;
    if (aid != null && aid.isNotEmpty && _assetIdLoaded != aid) {
      try {
        final info = await assetsRepo.getById(aid);
        if (!mounted) return;
        setState(() {
          _asset = info;
          _assetIdLoaded = aid;
        });
      } catch (_) {}
    }

    // Requested by: work_orders.requested_by stores profiles.id (UUID). Fetch by id, display full_name.
    final rid = wo.requestedBy;
    if (rid != null && rid.isNotEmpty && _requesterIdLoaded != rid) {
      try {
        final info = await profilesRepo.getById(rid);
        if (!mounted) return;
        setState(() {
          _requester = info;
          _requesterIdLoaded = rid;
        });
      } catch (_) {}
    }
    // Location: work_orders.location_id stores locations.id (UUID). Fetch by id, display location_id.
    final lid = wo.locationId;
    if (lid != null && lid.isNotEmpty && _locationIdLoaded != lid) {
      try {
        final info = await locationsRepo.getById(lid);
        if (!mounted) return;
        setState(() {
          _location = info;
          _locationIdLoaded = lid;
        });
      } catch (_) {}
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = repo.getById(widget.id);
    });
    await _future;
    await _loadAttachments();
    _asset = null; _location = null; _assetIdLoaded = null; _locationIdLoaded = null;
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
      if (kIsWeb) {
        final bytes = await xfile.readAsBytes();
        await attachmentsRepo.uploadBytes(widget.id, bytes, filename: xfile.name);
      } else {
        final file = File(xfile.path);
        await attachmentsRepo.upload(widget.id, file, filename: xfile.name);
      }
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Order Details'),
      ),
      body: ResponsiveConstraints(
        child: RefreshIndicator(
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
                  : '${two(d.day)}/${d.month}/${two(d.year % 100)}';

              final status = (wo.status ?? '').toLowerCase();
              // ensure asset/location names are loaded
              _ensureRefsLoaded(wo);
              // Lock checklist for Done and Review (and other final states)
              final isLocked =
                  status == 'completed' || status == 'done' || status == 'closed' || status == 'review' || status.contains('review');
              String toTitleCase(String s) {
                if (s.trim().isEmpty) return s;
                return s
                    .split(RegExp(r'\s+'))
                    .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1).toLowerCase()))
                    .join(' ');
              }

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                cacheExtent: 800,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Header section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          toTitleCase(wo.title ?? 'Untitled'),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${widget.id.split('-').first.toUpperCase()}',
                          style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if ((wo.status ?? '').isNotEmpty) StatusChip(wo.status!),
                            PriorityChip(wo.priority),
                            Chip(
                              label: Text(
                                'Due: ${fmtDate(wo.dueDate)}',
                                style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Key Info
                  SectionCard(
                    title: 'Key Info',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Created', value: fmtDate(wo.createdDate ?? wo.createdAt)),
                        _InfoRow(label: 'Due Date', value: fmtDate(wo.dueDate)),
                        _InfoRow(label: 'Requested By', value: _requester?.fullName ?? '-'),
                      ],
                    ),
                  ),

                  // Asset & Location moved into its own container
                  SectionCard(
                    title: 'Asset & Location',
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Asset', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(((_asset?.assetId ?? '-')).toUpperCase()),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: (_asset?.assetId ?? '').isEmpty
                              ? null
                              : () {
                                  final aid = _asset!.id;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AssetDetailsPage(id: aid),
                                    ),
                                  );
                                },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Location', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          subtitle: Text(((_location?.locationId ?? '-')).toUpperCase()),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: (_location?.locationId ?? '').isEmpty
                              ? null
                              : () {
                                  final humanId = _location!.locationId;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LocationDetailsPage(locationId: humanId),
                                    ),
                                  );
                                },
                        ),
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
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              const crossAxisCount = 3;
                              const spacing = 8.0;
                              final cellWidth = ((constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount).floor();
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: spacing,
                                  mainAxisSpacing: spacing,
                                ),
                                itemCount: _attachmentUrls.length,
                                itemBuilder: (context, index) {
                                  final url = _attachmentUrls[index];
                                  return RepaintBoundary(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () => showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            child: InteractiveViewer(
                                              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
                                            ),
                                          ),
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          memCacheWidth: cellWidth, // downscale decode to cell size
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          onPressed: (!isLocked && _tasks.every((t) => t.done))
                              ? () async {
                                  // TODO: call repository to mark as completed
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Thank you. Work order now is being reviewed')),
                                  );
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
