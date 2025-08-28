import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mra_cmms/models/work_order.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mra_cmms/repositories/assets_repository.dart';
import 'package:mra_cmms/repositories/locations_repository.dart';
import 'package:mra_cmms/models/profile.dart';
import 'package:mra_cmms/repositories/profiles_repository.dart';
import 'package:mra_cmms/features/assets/asset_details_page.dart';
import 'package:mra_cmms/features/locations/location_details_page.dart';
import 'package:mra_cmms/repositories/work_orders_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mra_cmms/repositories/notifications_repository.dart';

// ---- Section Widgets ----
class _HeaderSection extends StatelessWidget {
  final WorkOrder wo;
  final String id;
  const _HeaderSection({required this.wo, required this.id});

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDate(DateTime? d, [String? t]) {
    if (d == null) return '-';
    final dateStr = '${_two(d.day)}/${d.month}/${_two(d.year % 100)}';
    if (t != null && t.isNotEmpty) {
      return '$dateStr $t';
    }
    return dateStr;
  }

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
              if ((wo.status ?? '').isNotEmpty)
                Chip(
                  label: Text(
                    wo.status == 'Review'
                        ? 'In Review'
                        : wo.status == 'Done'
                        ? 'Approved'
                        : wo.status!,
                  ),
                ),
              Chip(label: Text('Priority')), // Placeholder
              Chip(
                label: Text(
                  'Appointment: ${_fmtDate(wo.appointmentDate, wo.appointmentTime)}',
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
  final String appointment;
  final String? appointmentTime;
  final String requesterName;
  final String? assigneeName;
  const _KeyInfoSection({
    required this.created,
    required this.appointment,
    this.appointmentTime,
    required this.requesterName,
    this.assigneeName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _InfoRow(label: 'Created', value: created),
          _InfoRow(label: 'Appointment Time', value: appointmentTime ?? '-'),
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

class _AttachmentsSection extends StatefulWidget {
  final List<String> attachmentUrls;
  final Future<void> Function(dynamic) onPick;
  const _AttachmentsSection({
    required this.attachmentUrls,
    required this.onPick,
  });

  @override
  State<_AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<_AttachmentsSection> {
  bool _picking = false;

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    setState(() => _picking = false);
    if (picked != null) {
      await widget.onPick(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text('Attachments'),
            trailing: IconButton(
              icon: _picking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt),
              tooltip: 'Take Photo',
              onPressed: _picking ? null : _pickImage,
            ),
          ),
          if (widget.attachmentUrls.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No attachments'),
            ),
          if (widget.attachmentUrls.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.attachmentUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final url = widget.attachmentUrls[i];
                  if (url.startsWith('/')) {
                    // Local file
                    return Image.file(
                      File(url),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    );
                  } else {
                    // Network image
                    return Image.network(
                      url,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    );
                  }
                },
              ),
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
  // TODO: Replace with real admin check
  final bool isAdmin = true;
  bool _reviewed = false;
  final List<String> _attachmentUrls = [];
  final List<File> _localImages = [];

  Future<void> _handlePick(dynamic picked) async {
    if (picked is XFile) {
      final file = File(picked.path);
      setState(() {
        _localImages.add(file);
      });
      final client = Supabase.instance.client;
      final woId = widget.id;
      final filename =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final storagePath = '$woId/$filename';
      final bytes = await file.readAsBytes();
      final res = await client.storage
          .from('work-order')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      if (!res.contains('error')) {
        final publicUrl = client.storage
            .from('work-order')
            .getPublicUrl(storagePath);
        setState(() {
          _attachmentUrls.add(publicUrl);
        });
        // Insert into work_order_attachments table
        final uuid = const Uuid().v4();
        await client.from('work_order_attachments').insert({
          'id': uuid,
          'work_order_id': woId,
          'url': publicUrl,
          'uploaded_at': DateTime.now().toIso8601String(),
        });

        // Restore: Send notification to both requester and assignee (if available)
        final wo = await _repo.getById(woId);
        if (wo != null) {
          final requesterId = wo.requestedBy;
          final assigneeId = wo.assignedTo;
          final recipients = <String>{};
          if (requesterId != null && requesterId.isNotEmpty)
            recipients.add(requesterId);
          if (assigneeId != null && assigneeId.isNotEmpty)
            recipients.add(assigneeId);
          if (recipients.isNotEmpty) {
            final notificationsRepo = NotificationsRepository();
            await notificationsRepo.create(
              userId: requesterId ?? assigneeId ?? '',
              module: 'Work Orders',
              action: 'attachment',
              entityId: woId,
              message:
                  'A new attachment was added to work order "${wo.title ?? woId}".',
              recipients: recipients.toList(),
            );
          }
        }
      }
    }
  }

  final _repo = WorkOrdersRepository();
  final _assetsRepo = AssetsRepository();
  final _locationsRepo = LocationsRepository();
  final _profilesRepo = ProfilesRepository();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkOrder?>(
      future: _repo.getById(widget.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Work order not found.')),
          );
        }
        final wo = snapshot.data!;
        return FutureBuilder<AssetLocationProfiles>(
          future: _fetchAssetLocationProfiles(wo),
          builder: (context, dataSnap) {
            final asset = dataSnap.data?.asset;
            final location = dataSnap.data?.location;
            final requester = dataSnap.data?.requester;
            final assignee = dataSnap.data?.assignee;
            return Scaffold(
              appBar: AppBar(title: const Text('Work Order Details')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderSection(wo: wo, id: wo.id),
                  const SizedBox(height: 16),
                  _KeyInfoSection(
                    created:
                        wo.createdDate?.toIso8601String().split('T').first ??
                        '-',
                    appointment:
                        wo.appointmentDate
                            ?.toIso8601String()
                            .split('T')
                            .first ??
                        '-',
                    appointmentTime: wo.appointmentTime,
                    requesterName:
                        requester?.fullName ?? (wo.requestedBy ?? '-'),
                    assigneeName: assignee?.fullName,
                  ),
                  const SizedBox(height: 16),
                  _AssetLocationSection(
                    asset: asset,
                    location: location,
                    onTapAsset: asset != null
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AssetDetailsPage(id: asset.id),
                              ),
                            );
                          }
                        : null,
                    onTapLocation: location != null
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LocationDetailsPage(
                                  locationId: location.locationId,
                                ),
                              ),
                            );
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _DescriptionSection(text: wo.description ?? '-'),
                  const SizedBox(height: 16),
                  _AttachmentsSection(
                    attachmentUrls: [
                      ..._attachmentUrls,
                      ..._localImages.map((f) => f.path),
                    ],
                    onPick: _handlePick,
                  ),
                  const SizedBox(height: 16),
                  const _ActivitySection(),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        icon: Icon(
                          wo.status == 'Done'
                              ? Icons.check_circle
                              : Icons.rate_review,
                        ),
                        label: Text(
                          wo.status == 'Done'
                              ? 'Approved'
                              : (wo.status == 'Review' && isAdmin)
                              ? 'Approve'
                              : (_reviewed || wo.status == 'Review')
                              ? 'Reviewed'
                              : 'Submit for Review',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed:
                            (wo.status == 'Done' ||
                                (_reviewed &&
                                    !(wo.status == 'Review' && isAdmin)))
                            ? null
                            : () async {
                                if (wo.status == 'Review' && isAdmin) {
                                  // Admin approves
                                  final (ok, err) = await _repo
                                      .updateStatusForAdmin(wo.id, 'Done');
                                  if (ok) {
                                    setState(() {
                                      _reviewed = true;
                                    });
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                              ? 'Work order approved!'
                                              : 'Failed: $err',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  // User submits for review
                                  final (ok, err) = await _repo
                                      .updateStatusForAdmin(wo.id, 'Review');
                                  if (ok) {
                                    setState(() {
                                      _reviewed = true;
                                    });
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                              ? 'Submitted for review!'
                                              : 'Failed: $err',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<AssetLocationProfiles> _fetchAssetLocationProfiles(
    WorkOrder wo,
  ) async {
    final asset = wo.assetId != null
        ? await _assetsRepo.getById(wo.assetId!)
        : null;
    final location = wo.locationId != null
        ? await _locationsRepo.getById(wo.locationId!)
        : null;
    final requester = wo.requestedBy != null
        ? await _profilesRepo.getById(wo.requestedBy!)
        : null;
    final assignee = wo.assignedTo != null
        ? await _profilesRepo.getById(wo.assignedTo!)
        : null;
    return AssetLocationProfiles(
      asset: asset,
      location: location,
      requester: requester,
      assignee: assignee,
    );
  }
}

class AssetLocationProfiles {
  final AssetInfo? asset;
  final LocationInfo? location;
  final Profile? requester;
  final Profile? assignee;
  AssetLocationProfiles({
    this.asset,
    this.location,
    this.requester,
    this.assignee,
  });
}
