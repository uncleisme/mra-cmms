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
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _locationIdCtrl = TextEditingController();
  final _assetIdCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _contactNumberCtrl = TextEditingController();

  DateTime? _dueDate;
  String _workType = 'Complaint';
  String _priority = 'Medium';

  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _locationIdCtrl.dispose();
    _assetIdCtrl.dispose();
    _contactPersonCtrl.dispose();
    _contactNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final repo = WorkOrdersRepository();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final (ok, err) = await repo.createWorkOrder(
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      workType: _workType,
      priority: _priority,
      dueDate: _dueDate,
      locationId: _locationIdCtrl.text.trim().isEmpty ? null : _locationIdCtrl.text.trim(),
      assetId: _assetIdCtrl.text.trim().isEmpty ? null : _assetIdCtrl.text.trim(),
      contactPerson: _contactPersonCtrl.text.trim().isEmpty ? null : _contactPersonCtrl.text.trim(),
      contactNumber: _contactNumberCtrl.text.trim().isEmpty ? null : _contactNumberCtrl.text.trim(),
      requestedBy: uid,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New Work Order')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *', hintText: 'Short summary'),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Description *', hintText: 'Describe the issue/work'),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _workType,
                decoration: const InputDecoration(labelText: 'Work type *'),
                items: const [
                  DropdownMenuItem(value: 'Complaint', child: Text('Complaint')),
                  DropdownMenuItem(value: 'Maintenance', child: Text('Maintenance')),
                  DropdownMenuItem(value: 'Repair', child: Text('Repair')),
                ],
                onChanged: (v) => setState(() => _workType = v ?? 'Complaint'),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationIdCtrl,
                decoration: const InputDecoration(labelText: 'Location ID (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _assetIdCtrl,
                decoration: const InputDecoration(labelText: 'Asset ID (optional)'),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPersonCtrl,
                decoration: const InputDecoration(labelText: 'Contact person (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNumberCtrl,
                decoration: const InputDecoration(labelText: 'Contact number (optional)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_submitting ? 'Creating...' : 'Create Work Order'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
