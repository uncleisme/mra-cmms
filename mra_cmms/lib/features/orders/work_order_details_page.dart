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
import 'package:mra_cmms/features/dashboard/dashboard_providers.dart';
import 'package:mra_cmms/repositories/notifications_repository.dart';

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
  final notificationsRepo = NotificationsRepository();
  late Future<WorkOrder?> _future;
  late List<_TaskItem> _tasks;
  List<String> _attachmentUrls = const [];
  AssetInfo? _asset;
  LocationInfo? _location;
  Profile? _requester;
  String? _assetIdLoaded;
  String? _locationIdLoaded;
  String? _requesterIdLoaded;
  bool _submittedForReview = false;

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
              final profileAsync = ref.watch(myProfileProvider);
              final isAdmin = profileAsync.maybeWhen(
                data: (p) => ((p?.type ?? '').toLowerCase() == 'admin'),
                orElse: () => false,
              );
              // ensure asset/location names are loaded
              _ensureRefsLoaded(wo);
              // Lock checklist for Done and Review (and other final states)
              final isLocked =
                  status == 'completed' || status == 'done' || status == 'closed' || status == 'review' || status.contains('review');
              final isDisabled = isLocked || _submittedForReview;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                cacheExtent: 800,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _HeaderSection(wo: wo, id: widget.id),

                  FutureBuilder<Profile?>(
                    future: wo.assignedTo != null && wo.assignedTo!.isNotEmpty ? profilesRepo.getById(wo.assignedTo!) : Future.value(null),
                    builder: (context, assigneeSnap) {
                      final assigneeName = assigneeSnap.data?.fullName;
                      return _KeyInfoSection(
                        created: fmtDate(wo.createdDate ?? wo.createdAt),
                        due: fmtDate(wo.dueDate),
                        requesterName: _requester?.fullName ?? '-',
                        assigneeName: assigneeName,
                      );
                    },
                  ),

                  _AssetLocationSection(
                    asset: _asset,
                    location: _location,
                    onTapAsset: (_asset?.assetId ?? '').isEmpty
                        ? null
                        : () {
                            final aid = _asset!.id;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AssetDetailsPage(id: aid),
                              ),
                            );
                          },
                    onTapLocation: (_location?.locationId ?? '').isEmpty
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

                  if ((wo.description ?? '').isNotEmpty)
                    _DescriptionSection(text: wo.description!),

                  _AttachmentsSection(
                    attachmentUrls: _attachmentUrls,
                    onPick: _pickAndUpload,
                  ),

                  const _ActivitySection(),

                  _CompletionSection(
                    tasks: _tasks,
                    isLocked: isLocked,
                    isDisabled: isDisabled,
                    status: status,
                    isAdmin: isAdmin,
                    onToggleTask: isLocked
                        ? null
                        : (idx, v) => setState(() => _tasks[idx].done = v),
                    onSubmitReview: (!isDisabled && _tasks.every((t) => t.done))
                        ? () async {
                            setState(() => _submittedForReview = true);
                            final result = await repo.updateStatus(widget.id, 'Review');
                            final ok = result.$1;
                            final error = result.$2;
                            if (!context.mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Thank you. Work order is now in Review')),
                              );
                              final _ = [
                                ref.refresh(kpisProvider),
                                ref.refresh(todaysOrdersProvider),
                                ref.refresh(recentNotificationsProvider),
                              ];
                              await _refresh();
                            } else {
                              setState(() => _submittedForReview = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to submit for review. ${error ?? 'Please try again.'}')),
                              );
                            }
                          }
                        : null,
                    onAdminApprove: (isAdmin && status == 'review')
                        ? () async {
                            final (ok, err) = await repo.updateStatusForAdmin(widget.id, 'Done');
                            if (!context.mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Approved. Status set to Done.')),
                              );
                              try {
                                final wo = await repo.getById(widget.id);
                                final title = (wo?.title ?? 'Work order');
                                final msg = '$title has been approved as Done';
                                final rid = wo?.requestedBy;
                                final aid = wo?.assignedTo;
                                if (rid != null && rid.isNotEmpty) {
                                  await notificationsRepo.create(
                                    userId: rid,
                                    module: 'Work Orders',
                                    action: 'approved',
                                    entityId: widget.id,
                                    message: msg,
                                  );
                                }
                                if (aid != null && aid.isNotEmpty && aid != rid) {
                                  await notificationsRepo.create(
                                    userId: aid,
                                    module: 'Work Orders',
                                    action: 'approved',
                                    entityId: widget.id,
                                    message: msg,
                                  );
                                }
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Notification not created: $e')),
                                );
                              }
                              ref.invalidate(kpisProvider);
                              ref.invalidate(todaysOrdersProvider);
                              ref.invalidate(recentNotificationsProvider);
                              ref.invalidate(pendingReviewsProvider);
                              await _refresh();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Approve failed: ${err ?? 'Unknown error'}')),
                              );
                            }
                          }
                        : null,
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

class _HeaderSection extends StatelessWidget {
  final WorkOrder wo;
  final String id;
  const _HeaderSection({required this.wo, required this.id});

  String _toTitleCase(String s) {
    if (s.trim().isEmpty) return s;
    return s
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1).toLowerCase()))
        .join(' ');
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime? d) => d == null ? '-' : '${_two(d.day)}/${d.month}/${_two(d.year % 100)}';

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
            _toTitleCase(wo.title ?? 'Untitled'),
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${id.split('-').first.toUpperCase()}',
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
                  'Due: ${_fmtDate(wo.dueDate)}',
                  style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
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
  const _KeyInfoSection({required this.created, required this.due, required this.requesterName, this.assigneeName});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Key Info',
      child: Column(
        children: [
          _InfoRow(label: 'Created', value: created),
          _InfoRow(label: 'Due Date', value: due),
          _InfoRow(label: 'Requested By', value: requesterName),
          if (assigneeName != null) _InfoRow(label: 'Assigned To', value: assigneeName!),
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
  const _AssetLocationSection({required this.asset, required this.location, this.onTapAsset, this.onTapLocation});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Asset & Location',
      child: Column(
        children: [
          ListTile(
            key: ValueKey('asset-${asset?.id ?? ''}'),
            contentPadding: EdgeInsets.zero,
            title: Text('Asset', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(((asset?.assetId ?? '-')).toUpperCase()),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTapAsset,
          ),
          const Divider(height: 1),
          ListTile(
            key: ValueKey('location-${location?.locationId ?? ''}'),
            contentPadding: EdgeInsets.zero,
            title: Text('Location', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
    return SectionCard(
      title: 'Description',
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  final List<String> attachmentUrls;
  final Future<void> Function(ImageSource) onPick;
  const _AttachmentsSection({required this.attachmentUrls, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Attachments',
      actions: [
        IconButton(
          tooltip: 'Add from camera',
          onPressed: () => onPick(ImageSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
        ),
        IconButton(
          tooltip: 'Add from gallery',
          onPressed: () => onPick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
        ),
      ],
      child: attachmentUrls.isEmpty
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
                  itemCount: attachmentUrls.length,
                  itemBuilder: (context, index) {
                    final url = attachmentUrls[index];
                    return RepaintBoundary(
                      key: ValueKey(url),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.hardEdge,
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
                            memCacheWidth: cellWidth,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: 'Activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No activity yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ],
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
  final Future<void> Function()? onAdminApprove;

  const _CompletionSection({
    required this.tasks,
    required this.isLocked,
    required this.isDisabled,
    required this.status,
    required this.isAdmin,
    this.onToggleTask,
    this.onSubmitReview,
    this.onAdminApprove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Completion',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'This job is completed. Checklist is read-only.',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ...List.generate(tasks.length, (i) {
            final t = tasks[i];
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(t.title),
              value: t.done,
              onChanged: isLocked
                  ? null
                  : (v) {
                      if (onToggleTask != null) {
                        onToggleTask!(i, v ?? false);
                      }
                    },
            );
          }),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              backgroundColor: isDisabled ? scheme.surfaceContainerHighest : null,
              foregroundColor: isDisabled ? scheme.onSurface : null,
            ),
            onPressed: onSubmitReview,
            icon: const Icon(Icons.check_circle),
            label: Text(
              isDisabled
                  ? ((status == 'done' || status == 'completed' || status == 'closed') ? 'Done' : 'Reviewed')
                  : 'Complete job',
            ),
          ),
          const SizedBox(height: 12),
          if (isAdmin && status == 'review')
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              onPressed: onAdminApprove,
              icon: const Icon(Icons.task_alt),
              label: const Text('Approve as Done (Admin)'),
            ),
        ],
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
