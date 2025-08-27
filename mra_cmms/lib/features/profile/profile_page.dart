import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../dashboard/dashboard_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/profile.dart';
import '../../repositories/profiles_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                hintText: 'Enter new password',
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Min 6 characters' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, controller.text);
                }
              },
              child: const Text('Change'),
            ),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: result),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully')),
          );
        }
      } on AuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed: ${e.message}')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update password')),
          );
        }
      }
    }
  }

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
    final formKey = GlobalKey<FormState>();
    final val = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit name'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  maxLength: 15,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter name';
                    if (v.trim().length > 15) return 'Max 15 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tip: Name is limited to 15 characters (including spaces).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (val != null && val.isNotEmpty) {
      await repo.updateName(val);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name updated')));
      }
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
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
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

            final nameStyle = Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700);
            final emailStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            );

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(p.avatarUrl!)
                          : null,
                      child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                          ? const Icon(
                              Icons.person,
                              size: 48,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      p.fullName ?? '-',
                      style: nameStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.email ?? '-',
                      style: emailStyle,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(Icons.edit),
                          title: const Text('Edit Name'),
                          subtitle: Text(p.fullName ?? '-'),
                          onTap: () => _editName(p),
                        ),
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
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your account password'),
                          onTap: _changePassword,
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
                  child: ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    subtitle: const Text('Sign out of your account'),
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      final confirm =
                          await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign out?'),
                              content: const Text(
                                'Are you sure you want to sign out?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!confirm) return;
                      await Supabase.instance.client.auth.signOut();
                      // Clear all user-related Hive boxes
                      await Future.wait([
                        Hive.box<Map>('profiles_box').clear(),
                        Hive.box<Map>('assets_box').clear(),
                        Hive.box<Map>('leaves_box').clear(),
                        Hive.box<Map>('work_orders_box').clear(),
                        Hive.box<Map>('locations_box').clear(),
                      ]);
                      // Invalidate dashboard-related providers
                      if (mounted) {
                        final container = ProviderScope.containerOf(
                          context,
                          listen: false,
                        );
                        container.invalidate(kpisProvider);
                        container.invalidate(todaysOrdersProvider);
                        container.invalidate(pendingReviewsProvider);
                        container.invalidate(todaysLeavesProvider);
                        container.invalidate(pendingLeavesForApprovalProvider);
                        container.invalidate(myProfileProvider);
                        container.invalidate(recentNotificationsProvider);
                        // Add more if needed
                      }
                      if (!mounted) return;
                      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
