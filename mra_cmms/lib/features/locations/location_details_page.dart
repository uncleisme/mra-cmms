import 'package:flutter/material.dart';
import 'package:mra_cmms/repositories/locations_repository.dart';

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
              return ListView(children: const [
                SizedBox(height: 80),
                Center(child: Text('Location not found')),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(loc.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Location ID: ${loc.locationId}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text('UUID: ${loc.id}', style: Theme.of(context).textTheme.bodyMedium),
              ],
            );
          },
        ),
      ),
    );
  }
}
