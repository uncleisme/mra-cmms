import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../repositories/work_orders_repository.dart';

class NewWorkOrderPage extends ConsumerStatefulWidget {
  const NewWorkOrderPage({super.key});

  @override
  ConsumerState<NewWorkOrderPage> createState() => _NewWorkOrderPageState();
}

class _NewWorkOrderPageState extends ConsumerState<NewWorkOrderPage> {
  int _currentStep = 0;

  // Form Key for step validation
  final _step2Key = GlobalKey<FormState>();

  // Step 1: Job Type
  String _workType = 'Complaint';

  // Step 2: Title & Description
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  // Step 3: Asset & Location
  String? _selectedAssetId;
  String? _selectedLocationId;

  // Step 4: Due Date
  DateTime? _dueDate;

  // Step 5: Assignment & Priority
  String? _selectedAssigneeId; // technician
  String _priority = 'Medium';

  // Step 6: Service Provider (conditional)
  String? _selectedServiceProviderId;

  // Data & State
  bool _submitting = false;
  bool _loadingLookups = true;
  List<Map<String, dynamic>> _assets = const [];
  List<Map<String, String>> _locations = const [];
  List<Map<String, String>> _technicians = const [];
  List<Map<String, String>> _serviceProviders = const [];

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    // print('Starting _loadLookups...');
    if (mounted) {
      setState(() {
        _loadingLookups = true;
      });
    }

    try {
      final client = Supabase.instance.client;

      // print('Fetching assets...');
      final assetsResponse = await client
          .from('assets')
          .select('id, asset_name, location_id')
          .order('asset_name')
          .limit(500);

      // print('Raw assets response: $assetsResponse');

      final assetsData =
          (assetsResponse as List?)?.cast<Map<String, dynamic>>() ?? [];
      // print('Found ${assetsData.length} assets');

      if (assetsData.isNotEmpty) {
        // print('First asset data: ${assetsData.first}');
      }

      // Fetch other data in parallel
      // print('Fetching locations...');
      final locationsFuture = client
          .from('locations')
          .select('id, name')
          .limit(500);

      // print('Fetching technicians...');
      final techsFuture = client
          .from('profiles')
          .select('id, full_name, type')
          .eq('type', 'technician');

      // print('Fetching service providers...');
      final providersFuture = client
          .from('contacts')
          .select('id, name')
          .eq('type', 'Service Provider')
          .limit(500);

      // print('Waiting for all data to load...');
      final results = await Future.wait([
        locationsFuture,
        techsFuture,
        providersFuture,
      ]);

      if (!mounted) {
        // print('Widget not mounted, aborting...');
        return;
      }

      // print('Processing data...');
      final newAssets = assetsData
          .map(
            (e) => {
              'id': e['id']?.toString() ?? '',
              'asset_name': e['asset_name']?.toString() ?? 'Unnamed Asset',
              'location_id': e['location_id']?.toString(),
            },
          )
          .toList();

      // print('Mapped ${newAssets.length} assets');
      if (newAssets.isNotEmpty) {
        // print('First mapped asset: ${newAssets.first}');
      }

      final newLocations = (results[0] as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {'id': m['id'].toString(), 'label': m['name'].toString()};
      }).toList();
      // print('Mapped ${newLocations.length} locations');

      final newTechnicians = (results[1] as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {'id': m['id'].toString(), 'label': m['full_name'].toString()};
      }).toList();
      // print('Mapped ${newTechnicians.length} technicians');

      final newServiceProviders = (results[2] as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {'id': m['id'].toString(), 'label': m['name'].toString()};
      }).toList();
      // print('Mapped ${newServiceProviders.length} service providers');

      if (mounted) {
        setState(() {
          _assets = newAssets;
          _locations = newLocations;
          _technicians = newTechnicians;
          _serviceProviders = newServiceProviders;
          _loadingLookups = false;
        });
        // print('State updated with new data');
      }
    } catch (e) {
      // print('Error in _loadLookups: $e');
      if (mounted) {
        setState(() => _loadingLookups = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    bool isStepValid = true;
    if (_currentStep == 1) {
      isStepValid = _step2Key.currentState!.validate();
    }

    if (isStepValid) {
      setState(() {
        if (_currentStep == 4 && _workType != 'Job') {
          _submit(); // Skip step 6 if not a 'Job'
        } else if (_currentStep < 5) {
          _currentStep++;
        } else {
          _submit();
        }
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  String _getLocationNameById(String? locationId) {
    if (locationId == null) return 'N/A';
    final location = _locations.firstWhere(
      (l) => l['id'] == locationId,
      orElse: () => {'label': 'Unknown Location'},
    );
    return location['label']!;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final repo = WorkOrdersRepository();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final (ok, err) = await repo.createWorkOrder(
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      workType: _workType,
      priority: _priority,
      dueDate: _dueDate,
      locationId: _selectedLocationId,
      assetId: _selectedAssetId,
      requestedBy: uid,
      assignedTo: _selectedAssigneeId,
      serviceProviderId: _selectedServiceProviderId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Work order created')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $err')));
    }
  }

  List<Widget> _buildSteps(BuildContext context) {
    return [
      // Step 1: Choose Job Type
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Step 1: Choose Job Type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _workType,
            decoration: const InputDecoration(labelText: 'Work type *'),
            items: const [
              DropdownMenuItem(value: 'Preventive', child: Text('Preventive')),
              DropdownMenuItem(value: 'Complaint', child: Text('Complaint')),
              DropdownMenuItem(value: 'Job', child: Text('Job')),
              DropdownMenuItem(value: 'Repair', child: Text('Repair')),
            ],
            onChanged: (v) => setState(() => _workType = v ?? 'Complaint'),
          ),
        ],
      ),

      // Step 2: Title and Description
      Form(
        key: _step2Key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Step 2: Title and Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'Short summary',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe the issue/work',
              ),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Description is required'
                  : null,
            ),
          ],
        ),
      ),

      // Step 3: Asset and Location
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Step 3: Asset and Location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _loadingLookups
              ? const Center(child: CircularProgressIndicator())
              : _assets.isEmpty
              ? const Text('No assets available')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Asset',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedAssetId,
                          isExpanded: true,
                          hint: const Text('Select an asset'),
                          items: _assets.map<DropdownMenuItem<String>>((asset) {
                            final assetName =
                                asset['asset_name']?.toString() ??
                                'Unnamed Asset';
                            final assetId = asset['id']?.toString();
                            return DropdownMenuItem<String>(
                              value: assetId,
                              child: Text(
                                assetName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            if (value == null) return;
                            setState(() {
                              _selectedAssetId = value;
                              final selectedAsset = _assets.firstWhere(
                                (a) => a['id']?.toString() == value,
                                orElse: () => <String, String?>{},
                              );
                              if (selectedAsset.isNotEmpty) {
                                _selectedLocationId =
                                    selectedAsset['location_id']?.toString();
                              } else {
                                _selectedLocationId = null;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(
              _selectedLocationId,
            ), // Ensures field rebuilds when ID changes
            initialValue: _getLocationNameById(_selectedLocationId),
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Location (auto-filled)',
              border: InputBorder.none,
              filled: true,
            ),
          ),
        ],
      ),

      // Step 4: Due Date
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Step 4: Due Date',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? now,
                firstDate: now.subtract(const Duration(days: 0)),
                lastDate: now.add(const Duration(days: 365 * 2)),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Due date (optional)',
              ),
              child: Text(
                _dueDate == null
                    ? 'Not set'
                    : _dueDate!.toString().split(' ').first,
              ),
            ),
          ),
        ],
      ),

      // Step 5: Assigned To & Priority
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Step 5: Assignment and Priority',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedAssigneeId,
            decoration: const InputDecoration(
              labelText: 'Assign to technician (optional)',
            ),
            items: _technicians.map((tech) {
              return DropdownMenuItem(
                value: tech['id'],
                child: Text(tech['label']!),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedAssigneeId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priority *'),
            items: const [
              DropdownMenuItem(value: 'Low', child: Text('Low')),
              DropdownMenuItem(value: 'Medium', child: Text('Medium')),
              DropdownMenuItem(value: 'High', child: Text('High')),
            ],
            onChanged: (v) => setState(() => _priority = v ?? 'Medium'),
          ),
        ],
      ),

      // Step 6: Service Provider (for 'Job' type)
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Step 6: Service Provider',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedServiceProviderId,
            decoration: const InputDecoration(
              labelText: 'Service Provider (optional)',
            ),
            items: _serviceProviders.map((sp) {
              return DropdownMenuItem(
                value: sp['id'],
                child: Text(sp['label']!),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedServiceProviderId = v),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = _buildSteps(context);
    final isLastStep =
        _currentStep == steps.length - 1 ||
        (_currentStep == 4 && _workType != 'Job');

    return Scaffold(
      appBar: AppBar(title: Text('New Work Order (Step ${_currentStep + 1})')),
      body: _loadingLookups
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _currentStep, children: steps),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              TextButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                onPressed: _previousStep,
              )
            else
              const SizedBox(), // Keep space

            FilledButton.icon(
              onPressed: _submitting ? null : _nextStep,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(isLastStep ? Icons.check : Icons.arrow_forward),
              label: Text(
                _submitting ? 'Creating...' : (isLastStep ? 'Submit' : 'Next'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
