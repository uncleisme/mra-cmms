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
    try {
      final client = Supabase.instance.client;
      final assetsData = await client
          .from('assets')
          .select('id, asset_name, location_id')
          .order('asset_name')
          .limit(500) as List;
      final locationsData = await client
          .from('locations')
          .select('id, name')
          .limit(500) as List;
      final techsData = await client
          .from('profiles')
          .select('id, full_name, type')
          .or('type.eq.technician,type.eq.Technician') as List;
      final providersData = await client
          .from('contacts') // Assuming 'contacts' table for service providers
          .select('id, name')
          .eq('type', 'Service Provider')
          .limit(500) as List;

      setState(() {
        _assets = assetsData.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        _locations = locationsData.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return {'id': m['id'].toString(), 'label': m['name'].toString()};
        }).toList();

        _technicians = techsData.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return {'id': m['id'].toString(), 'label': m['full_name'].toString()};
        }).toList();

        _serviceProviders = providersData.map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return {'id': m['id'].toString(), 'label': m['name'].toString()};
        }).toList();

        _loadingLookups = false;
      });
    } catch (e) {
      setState(() => _loadingLookups = false);
      if (mounted) {
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Work order created')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $err')));
    }
  }

  List<Widget> _buildSteps(BuildContext context) {
    return [
      // Step 1: Choose Job Type
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Step 1: Choose Job Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _workType,
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
            const Text('Step 2: Title and Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *', hintText: 'Short summary'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(labelText: 'Description *', hintText: 'Describe the issue/work'),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
            ),
          ],
        ),
      ),

      // Step 3: Asset and Location
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Step 3: Asset and Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedAssetId,
            decoration: const InputDecoration(labelText: 'Asset (optional)'),
            items: _assets.map((asset) {
              return DropdownMenuItem(value: asset['id'].toString(), child: Text(asset['asset_name'].toString()));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedAssetId = value;
                final selectedAsset = _assets.firstWhere((a) => a['id'] == value, orElse: () => {});
                _selectedLocationId = selectedAsset.isNotEmpty ? selectedAsset['location_id']?.toString() : null;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedLocationId,
            decoration: const InputDecoration(labelText: 'Location (auto-filled)'),
            items: _locations.map((loc) {
              return DropdownMenuItem(value: loc['id'], child: Text(loc['label']!));
            }).toList(),
            onChanged: null, // Disabled
          ),
        ],
      ),

      // Step 4: Due Date
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Step 4: Due Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              decoration: const InputDecoration(labelText: 'Due date (optional)'),
              child: Text(_dueDate == null ? 'Not set' : _dueDate!.toString().split(' ').first),
            ),
          ),
        ],
      ),

      // Step 5: Assigned To & Priority
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Step 5: Assignment and Priority', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedAssigneeId,
            decoration: const InputDecoration(labelText: 'Assign to technician (optional)'),
            items: _technicians.map((tech) {
              return DropdownMenuItem(value: tech['id'], child: Text(tech['label']!));
            }).toList(),
            onChanged: (v) => setState(() => _selectedAssigneeId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _priority,
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
          const Text('Step 6: Service Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedServiceProviderId,
            decoration: const InputDecoration(labelText: 'Service Provider (optional)'),
            items: _serviceProviders.map((sp) {
              return DropdownMenuItem(value: sp['id'], child: Text(sp['label']!));
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
    final isLastStep = _currentStep == steps.length - 1 || (_currentStep == 4 && _workType != 'Job');

    return Scaffold(
      appBar: AppBar(title: Text('New Work Order (Step ${_currentStep + 1})')),
      body: _loadingLookups
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentStep,
              children: steps,
            ),
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
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isLastStep ? Icons.check : Icons.arrow_forward),
              label: Text(_submitting ? 'Creating...' : (isLastStep ? 'Submit' : 'Next')),
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
