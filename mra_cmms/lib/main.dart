import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'core/hive_init.dart';
import 'repositories/work_orders_repository.dart';
import 'repositories/leaves_repository.dart';
import 'models/work_order.dart';
import 'models/leave.dart';
import 'core/theme/theme.dart';
import 'core/theme/util.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/app_text_field.dart';
import 'core/widgets/app_button.dart';
import 'core/widgets/status_chip.dart';
import 'core/widgets/primary_nav.dart';
import 'core/widgets/home_shell.dart';
import 'core/widgets/empty_state.dart';
import 'features/profile/profile_page.dart';
import 'features/dashboard/dashboard_providers.dart';
import 'core/widgets/kpi_card.dart';
import 'core/widgets/section_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await HiveInit.openCoreBoxes();
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    // Build text theme using Google Fonts util; change fonts as desired
    final textTheme = createTextTheme(context, 'Inter', 'Inter');
    final materialTheme = MaterialTheme(textTheme);
    return MaterialApp(
      title: 'MRA CMMS',
      theme: materialTheme.light(),
      darkTheme: materialTheme.dark(),
      themeMode: mode,
      routes: {
        '/': (_) => const AuthGate(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/dashboard': (_) => const HomeShell(initialIndex: 0),
        '/orders': (_) => const HomeShell(initialIndex: 1),
        '/leaves': (_) => const HomeShell(initialIndex: 2),
        '/settings': (_) => const HomeShell(initialIndex: 3),
        '/profile': (_) => const ProfilePage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const LoginPage();
    }
    return const HomeShell();
  }
}

// Placeholder pages
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Future<void> login() async {
      if (!formKey.currentState!.validate()) return;
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } on AuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: passwordController,
                    label: 'Password',
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                  ),
                  const SizedBox(height: 20),
                  AppButton(label: 'Sign In', onPressed: login),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Future<void> register() async {
      if (!formKey.currentState!.validate()) return;
      try {
        final res = await Supabase.instance.client.auth.signUp(
          email: emailController.text.trim(),
          password: passwordController.text,
          data: {'full_name': nameController.text.trim()},
        );
        if (res.user != null) {
          // Optionally create a profile row via trigger or here
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registered. Please verify if required, then sign in.')),
            );
            Navigator.pop(context);
          }
        }
      } on AuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameController,
                    label: 'Full name',
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: passwordController,
                    label: 'Password',
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 chars' : null,
                  ),
                  const SizedBox(height: 20),
                  AppButton(label: 'Create account', onPressed: register),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardPage extends ConsumerWidget {
  final bool showNav;
  const DashboardPage({super.key, this.showNav = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(kpisProvider);
    final todaysOrders = ref.watch(todaysOrdersProvider);
    final todaysLeaves = ref.watch(todaysLeavesProvider);
    final activities = ref.watch(recentActivitiesProvider);
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          profile.when(
                            data: (p) {
                              final name = (p?.fullName?.trim().isNotEmpty ?? false) ? p!.fullName!.trim().split(' ').first : 'there';
                              final hour = DateTime.now().hour;
                              final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
                              return Text('$greeting, $name', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600));
                            },
                            loading: () => const SizedBox(height: 20, width: 140, child: LinearProgressIndicator()),
                            error: (e, st) => const Text('Welcome'),
                          ),
                          const SizedBox(height: 4),
                          StreamBuilder<DateTime>(
                            stream: Stream<DateTime>.periodic(const Duration(seconds: 30), (_) => DateTime.now()),
                            builder: (context, snap) {
                              final now = snap.data ?? DateTime.now();
                              String two(int n) => n.toString().padLeft(2, '0');
                              final date = '${now.year}-${two(now.month)}-${two(now.day)}';
                              final time = '${two(now.hour)}:${two(now.minute)}';
                              return Text('$date • $time', style: Theme.of(context).textTheme.bodySmall);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    profile.when(
                      data: (p) {
                        final avatarUrl = p?.avatarUrl;
                        return InkWell(
                          onTap: () => Navigator.pushNamed(context, '/profile'),
                          borderRadius: BorderRadius.circular(24),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty) ? const Icon(Icons.person_outline, size: 20) : null,
                          ),
                        );
                      },
                      loading: () => const CircleAvatar(radius: 18, child: Icon(Icons.person_outline, size: 20)),
                      error: (e, st) => const CircleAvatar(radius: 18, child: Icon(Icons.person_outline, size: 20)),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionCard(
              title: "Today's orders",
              onSeeAll: () => Navigator.pushNamed(context, '/orders'),
              child: todaysOrders.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const ListTile(
                      leading: Icon(Icons.assignment_outlined),
                      title: Text('No orders for today'),
                      subtitle: Text('You are all caught up.'),
                    );
                  }
                  bool isSameDay(DateTime a, DateTime b) =>
                      a.year == b.year && a.month == b.month && a.day == b.day;
                  bool isToday(DateTime? d) {
                    if (d == null) return false;
                    final now = DateTime.now();
                    final local = d.toLocal();
                    return isSameDay(local, now);
                  }
                  DateTime? effectiveDate(wo) {
                    final status = (wo.status ?? '').toLowerCase();
                    final dueToday = isToday(wo.dueDate);
                    final completed = status == 'completed' || status == 'done' || status == 'closed';
                    final nextToday = completed && isToday(wo.nextScheduledDate);
                    if (dueToday) return wo.dueDate?.toLocal();
                    if (nextToday) return wo.nextScheduledDate?.toLocal();
                    return null;
                  }
                  // Keep only orders that are due today, or if completed, whose next schedule is today
                  final todayRelevant = items.where((wo) => effectiveDate(wo) != null).toList();
                  // Sort by effective time ascending (earliest first)
                  todayRelevant.sort((a, b) {
                    final ad = effectiveDate(a);
                    final bd = effectiveDate(b);
                    if (ad == null && bd == null) return 0;
                    if (ad == null) return 1;
                    if (bd == null) return -1;
                    return ad.compareTo(bd);
                  });
                  if (todayRelevant.isEmpty) {
                    return const ListTile(
                      leading: Icon(Icons.assignment_outlined),
                      title: Text('No orders for today'),
                      subtitle: Text('You are all caught up.'),
                    );
                  }
                  final visible = todayRelevant.take(5).toList();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final wo = visible[i];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: const Icon(Icons.build_outlined),
                        title: Text(wo.title ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Row(children: [if ((wo.status ?? '').isNotEmpty) StatusChip(wo.status!), const SizedBox(width: 8), Text(wo.priority ?? '-')]),
                        trailing: FilledButton.icon(
                          onPressed: () {/* start action pending */},
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/orders'),
                      );
                    },
                  );
                },
                loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
                error: (e, st) => const ListTile(title: Text("Failed to load today's orders")),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: kpis.when(
                data: (v) {
                  final scheme = Theme.of(context).colorScheme;
                  final cards = [
                    KpiCard(
                      label: 'Open',
                      value: v['open'] ?? 0,
                      icon: Icons.inbox_outlined,
                      color: scheme.primary,
                      onTap: () => Navigator.pushNamed(context, '/orders'),
                    ),
                    KpiCard(
                      label: 'In progress',
                      value: v['in_progress'] ?? 0,
                      icon: Icons.play_circle_outline,
                      color: scheme.tertiary,
                      onTap: () => Navigator.pushNamed(context, '/orders'),
                    ),
                    KpiCard(
                      label: 'Overdue',
                      value: v['overdue'] ?? 0,
                      icon: Icons.warning_amber_outlined,
                      color: scheme.error,
                      onTap: () => Navigator.pushNamed(context, '/orders'),
                    ),
                  ];
                  final controller = PageController(viewportFraction: 0.85, keepPage: true);
                  return SizedBox(
                    height: 130,
                    child: PageView.builder(
                      controller: controller,
                      physics: const PageScrollPhysics(),
                      pageSnapping: true,
                      padEnds: true, // edge padding for first/last cards
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(right: index == cards.length - 1 ? 0 : 12),
                          child: cards[index],
                        );
                      },
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => const SizedBox.shrink(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionCard(
              title: "Today's leaves",
              onSeeAll: () => Navigator.pushNamed(context, '/leaves'),
              child: todaysLeaves.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const ListTile(
                      leading: Icon(Icons.beach_access_outlined),
                      title: Text('No leaves today'),
                      subtitle: Text('Enjoy your day!'),
                    );
                  }
                  final visible = items.take(5).toList();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final lv = visible[i];
                      final range = '${lv.startDate.toString().split(' ').first} → ${lv.endDate.toString().split(' ').first}';
                      return ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(lv.typeKey, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(lv.reason ?? ''),
                        isThreeLine: true,
                        minVerticalPadding: 8,
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusChip(lv.status),
                            const SizedBox(height: 4),
                            Text(range),
                          ],
                        ),
                        onTap: () => Navigator.pushNamed(context, '/leaves'),
                      );
                    },
                  );
                },
                loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
                error: (e, st) => const ListTile(title: Text("Failed to load today's leaves")),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionCard(
              title: 'Recent activity',
              child: activities.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const ListTile(
                      leading: Icon(Icons.notifications_none),
                      title: Text('No recent activity'),
                    );
                  }
                  final visible = items.take(6).toList();
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = visible[i];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: const Icon(Icons.notifications_active_outlined),
                        title: Text(n.title ?? 'Notification', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(n.body ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Text(n.createdAt.toLocal().toString().split('.').first),
                      );
                    },
                  );
                },
                loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
                error: (e, st) => const ListTile(title: Text('Failed to load activity')),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: showNav ? const PrimaryNavBar(currentIndex: 0) : null,
    );
  }
}

class OrdersPage extends StatefulWidget {
  final bool showNav;
  const OrdersPage({super.key, this.showNav = true});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final repo = WorkOrdersRepository();
  late Future<List<WorkOrder>> _future;
  String _query = '';
  String _sortKey = 'due'; // 'due' | 'priority' | 'status' | 'title'
  bool _ascending = false; // latest first by default

  @override
  void initState() {
    super.initState();
    _future = repo.getAssignedToMe();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = repo.getAssignedToMe();
    });
    await _future;
  }

  void _createOrder() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create Order coming soon')));
  }

  void _openSearch() async {
    final controller = TextEditingController(text: _query);
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search orders', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Title, status, or priority',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => Navigator.pop(context, v.trim()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text.trim()),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      setState(() => _query = result);
    }
  }

  void _openSort() async {
    final picked = await showModalBottomSheet<(String, bool)>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        String tempKey = _sortKey;
        bool tempAsc = _ascending;
        return StatefulBuilder(
          builder: (context, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ListTile(title: Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600))),
                    RadioListTile<String>(
                      value: 'due',
                      groupValue: tempKey,
                      title: const Text('Due date'),
                      onChanged: (v) => setLocal(() => tempKey = v!),
                    ),
                    RadioListTile<String>(
                      value: 'priority',
                      groupValue: tempKey,
                      title: const Text('Priority'),
                      onChanged: (v) => setLocal(() => tempKey = v!),
                    ),
                    RadioListTile<String>(
                      value: 'status',
                      groupValue: tempKey,
                      title: const Text('Status'),
                      onChanged: (v) => setLocal(() => tempKey = v!),
                    ),
                    RadioListTile<String>(
                      value: 'title',
                      groupValue: tempKey,
                      title: const Text('Title'),
                      onChanged: (v) => setLocal(() => tempKey = v!),
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: tempAsc,
                      title: const Text('Ascending'),
                      onChanged: (v) => setLocal(() => tempAsc = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, (tempKey, tempAsc)),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() {
        _sortKey = picked.$1;
        _ascending = picked.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onPressed: _openSort,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<WorkOrder>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            List<WorkOrder> items = List.of(snapshot.data ?? []);
            // Filter by query
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              items = items.where((wo) {
                final t = (wo.title ?? '').toLowerCase();
                final s = (wo.status ?? '').toLowerCase();
                final p = (wo.priority ?? '').toLowerCase();
                return t.contains(q) || s.contains(q) || p.contains(q);
              }).toList();
            }
            // Sort
            int priorityRank(String? p) {
              switch ((p ?? '').toLowerCase()) {
                case 'high':
                  return 0;
                case 'medium':
                  return 1;
                case 'low':
                  return 2;
                default:
                  return 3;
              }
            }
            int cmp(WorkOrder a, WorkOrder b) {
              int res = 0;
              switch (_sortKey) {
                case 'priority':
                  res = priorityRank(a.priority).compareTo(priorityRank(b.priority));
                  break;
                case 'status':
                  res = (a.status ?? '').toLowerCase().compareTo((b.status ?? '').toLowerCase());
                  break;
                case 'title':
                  res = (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase());
                  break;
                case 'due':
                default:
                  final ad = a.dueDate;
                  final bd = b.dueDate;
                  if (ad == null && bd == null) res = 0;
                  else if (ad == null) res = 1; // nulls last
                  else if (bd == null) res = -1;
                  else res = ad.compareTo(bd);
              }
              return _ascending ? res : -res;
            }
            items.sort(cmp);
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No work orders',
                message: 'You have no assigned orders yet. Pull to refresh.',
                actionLabel: 'New order',
                onAction: _createOrder,
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final wo = items[i];
                return ListTile(
                  title: Text(wo.title ?? 'Untitled'),
                  subtitle: Row(
                    children: [
                      if ((wo.status ?? '').isNotEmpty) StatusChip(wo.status!),
                      const SizedBox(width: 8),
                      Text(wo.priority ?? '-')
                    ],
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Due', style: TextStyle(fontSize: 12)),
                      Text(wo.dueDate?.toString().split(' ').first ?? ''),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'orders_fab',
        onPressed: _createOrder,
        icon: const Icon(Icons.add),
        label: const Text('Order'),
      ),
      bottomNavigationBar: widget.showNav ? const PrimaryNavBar(currentIndex: 1) : null,
    );
  }
}

class LeavesPage extends StatefulWidget {
  final bool showNav;
  const LeavesPage({super.key, this.showNav = true});

  @override
  State<LeavesPage> createState() => _LeavesPageState();
}

class _LeavesPageState extends State<LeavesPage> {
  final repo = LeavesRepository();
  late Future<List<LeaveRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = repo.getMyLeaves();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = repo.getMyLeaves();
    });
    await _future;
  }

  void _createLeave() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create Leave coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaves'),
        actions: const [],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<LeaveRequest>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = List.of(snapshot.data ?? []);
            // Sort by most recent start date first (latest on top)
            items.sort((a, b) {
              final ad = a.startDate;
              final bd = b.startDate;
              if (ad == null && bd == null) return 0;
              if (ad == null) return 1; // nulls last
              if (bd == null) return -1;
              return bd.compareTo(ad); // descending
            });
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No leaves',
                message: 'No leave requests found. Pull to refresh or create one.',
                actionLabel: 'New leave',
                onAction: _createLeave,
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final lv = items[i];
                final range = '${lv.startDate.toString().split(' ').first} → ${lv.endDate.toString().split(' ').first}';
                return ListTile(
                  title: Text(lv.typeKey),
                  subtitle: Text(lv.reason ?? ''),
                  isThreeLine: true,
                  minVerticalPadding: 8,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(lv.status),
                      const SizedBox(height: 4),
                      Text(range),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'leaves_fab',
        onPressed: _createLeave,
        icon: const Icon(Icons.add),
        label: const Text('Leave'),
      ),
      bottomNavigationBar: widget.showNav ? const PrimaryNavBar(currentIndex: 2) : null,
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showNav = true});
  final bool showNav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    String modeLabel(ThemeMode m) =>
        m == ThemeMode.light ? 'Light' : m == ThemeMode.dark ? 'Dark' : 'System';
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('Theme'),
            subtitle: Text(modeLabel(mode)),
            onTap: () async {
              final controller = ref.read(themeModeProvider.notifier);
              final picked = await showModalBottomSheet<ThemeMode>(
                context: context,
                showDragHandle: true,
                builder: (context) {
                  return SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          groupValue: mode,
                          title: const Text('System'),
                          onChanged: (v) => Navigator.pop(context, v),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          groupValue: mode,
                          title: const Text('Light'),
                          onChanged: (v) => Navigator.pop(context, v),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          groupValue: mode,
                          title: const Text('Dark'),
                          onChanged: (v) => Navigator.pop(context, v),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                },
              );
              if (picked != null) controller.setMode(picked);
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Account', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('Photo, name, and details'),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          const Divider(height: 24),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Session', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: showNav ? const PrimaryNavBar(currentIndex: 3) : null,
    );
  }
}

// ProfilePage moved to features/profile/profile_page.dart
