import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart' as mime;
import '../../models/profile.dart';
import '../../repositories/profiles_repository.dart';
import '../../core/widgets/responsive_constraints.dart';

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
    String fmt(DateTime d) {
      String two(int n) => n.toString().padLeft(2, '0');
      final l = d.toLocal();
      return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
    }

    return Scaffold(
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

            final scheme = Theme.of(context).colorScheme;
            final nameStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.white);
            final emailStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  expandedHeight: 220,
                  title: const Text('Profile'),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.primaryContainer],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 44,
                                          backgroundColor: Colors.white24,
                                          backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                                              ? CachedNetworkImageProvider(p.avatarUrl!)
                                              : null,
                                          child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                                              ? const Icon(Icons.person, size: 44, color: Colors.white)
                                              : null,
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Material(
                                            color: scheme.secondary,
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
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: Text(p.fullName ?? '-', style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(p.email ?? '-', style: emailStyle),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ResponsiveConstraints(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                      child: Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  ListTile(
                                    leading: const Icon(Icons.email_outlined),
                                    title: const Text('Email'),
                                    subtitle: Text(p.email ?? '-'),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.badge_outlined),
                                    title: const Text('Role'),
                                    subtitle: Text(p.type ?? '-'),
                                  ),
                                  if (p.createdAt != null)
                                    ListTile(
                                      leading: const Icon(Icons.calendar_today_outlined),
                                      title: const Text('Joined'),
                                      subtitle: Text(fmt(p.createdAt!)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit_outlined),
                                  title: const Text('Edit name'),
                                  subtitle: const Text('Update your display name'),
                                  onTap: () => _editName(p),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.image_outlined),
                                  title: const Text('Change photo'),
                                  subtitle: const Text('Upload a new profile picture'),
                                  onTap: _changePhoto,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.logout),
                                  title: const Text('Sign out'),
                                  subtitle: const Text('Sign out of your account'),
                                  onTap: () async {
                                    final navigator = Navigator.of(context);
                                    final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Sign out?'),
                                            content: const Text('Are you sure you want to sign out?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (!confirm) return;
                                    await Supabase.instance.client.auth.signOut();
                                    if (!mounted) return;
                                    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
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
