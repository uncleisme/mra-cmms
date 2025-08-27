import 'package:flutter/material.dart';
import 'package:mra_cmms/repositories/locations_repository.dart';

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

class LocationDetailsPage extends StatefulWidget {
  final String locationId; // locations.location_id
  const LocationDetailsPage({super.key, required this.locationId});
  @override
  State<LocationDetailsPage> createState() => _LocationDetailsPageState();
}

class _LocationDetailsPageState extends State<LocationDetailsPage> {
  final repo = LocationsRepository();
  late Future<LocationInfo?> _future;

  @override
  void initState() {
    super.initState();
    _future = repo.getByLocationId(widget.locationId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = repo.getByLocationId(widget.locationId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Details')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<LocationInfo?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final loc = snap.data;
            if (loc == null) {
              return ListView(
                children: const [Center(child: Text('Location not found'))],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  loc.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(label: 'Location ID', value: loc.locationId),
                        _InfoRow(
                          label: 'Block',
                          value: (loc as dynamic).block ?? '-',
                        ),
                        _InfoRow(
                          label: 'Floor',
                          value: (loc as dynamic).floor ?? '-',
                        ),
                        _InfoRow(
                          label: 'Room',
                          value: (loc as dynamic).room ?? '-',
                        ),
                        _InfoRow(
                          label: 'Type',
                          value: (loc as dynamic).type ?? '-',
                        ),
                        _InfoRow(
                          label: 'Description',
                          value: (loc as dynamic).description ?? '-',
                        ),
                        _InfoRow(label: 'UUID', value: loc.id),
                        _InfoRow(
                          label: 'Created At',
                          value:
                              (loc as dynamic).createdAt
                                  ?.toString()
                                  .split(' ')
                                  .first ??
                              '-',
                        ),
                        _InfoRow(
                          label: 'Updated At',
                          value:
                              (loc as dynamic).updatedAt
                                  ?.toString()
                                  .split(' ')
                                  .first ??
                              '-',
                        ),
                      ],
                    ),
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
