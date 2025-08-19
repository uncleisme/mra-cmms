import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart' as mime;
import '../../models/profile.dart';
import '../../repositories/profiles_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final repo = ProfilesRepository();
  late Future<Profile?> _future;

  @override
  void initState() {
    super.initState();
    _future = repo.getMyProfile();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = repo.getMyProfile();
    });
    await _future;
  }

  Future<void> _editName(Profile p) async {
    final controller = TextEditingController(text: p.fullName ?? '');
    final val = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
          ],
        );
      },
    );
    if (val != null && val.isNotEmpty) {
      await repo.updateName(val);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name updated')));
      }
    }
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    final type = mime.lookupMimeType(xfile.name) ?? 'image/jpeg';
    await repo.uploadAvatar(bytes: bytes, filename: xfile.name, contentType: type);
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Profile?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final p = snapshot.data;
            if (p == null) {
              return const Center(child: Text('No profile found'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                          child: p.avatarUrl == null ? const Icon(Icons.person, size: 44) : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: Theme.of(context).colorScheme.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _changePhoto,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(p.fullName ?? '-', style: Theme.of(context).textTheme.titleLarge)),
                              IconButton(
                                tooltip: 'Edit name',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editName(p),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(p.email ?? '-', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: const Text('Role'),
                  subtitle: Text(p.type ?? '-'),
                ),
                if (p.createdAt != null)
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Created'),
                    subtitle: Text(p.createdAt!.toLocal().toString()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
