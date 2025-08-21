import 'package:flutter/material.dart';
import 'package:mra_cmms/core/widgets/section_card.dart';
import 'package:mra_cmms/repositories/assets_repository.dart';
import 'package:mra_cmms/repositories/locations_repository.dart';
import 'package:mra_cmms/features/locations/location_details_page.dart';

class AssetDetailsPage extends StatefulWidget {
  final String id; // assets.id (UUID primary key)
  const AssetDetailsPage({super.key, required this.id});

  @override
  State<AssetDetailsPage> createState() => _AssetDetailsPageState();
}

class _AssetDetailsPageState extends State<AssetDetailsPage> {
  final repo = AssetsRepository();
  final locationsRepo = LocationsRepository();
  late Future<AssetInfo?> _future;
  LocationInfo? _location;
  String? _locationIdLoaded;

  @override
  void initState() {
    super.initState();
    _future = repo.getById(widget.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = repo.getById(widget.id);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asset Details')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<AssetInfo?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final asset = snap.data;
            if (asset == null) {
              return ListView(children: const [
                SizedBox(height: 80),
                Center(child: Text('Asset not found')),
              ]);
            }

            // ensure location info is loaded
            final lid = asset.locationId;
            if (lid != null && lid.isNotEmpty && _locationIdLoaded != lid) {
              locationsRepo.getByLocationId(lid).then((info) {
                if (!mounted) return;
                setState(() {
                  _location = info;
                  _locationIdLoaded = lid;
                });
              });
            }

            final scheme = Theme.of(context).colorScheme;
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Code: '),
                                Text(asset.assetId),
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
                      _InfoRow(label: 'Asset ID', value: asset.assetId),
                      _InfoRow(label: 'UUID', value: asset.id),
                    ],
                  ),
                ),

                // Location section
                SectionCard(
                  title: 'Location',
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Location'),
                        subtitle: Text('${_location?.locationId ?? (asset.locationId ?? '-')} • ${_location?.name ?? '-'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: (asset.locationId ?? '').isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LocationDetailsPage(locationId: asset.locationId!),
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),

                // Placeholder for more asset sections
                SectionCard(
                  title: 'Details',
                  child: Text(
                    'More fields can be shown here as needed.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
