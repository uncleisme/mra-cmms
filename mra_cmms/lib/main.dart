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
import 'core/theme/typography.dart';
import 'core/widgets/app_text_field.dart';
import 'core/widgets/app_button.dart';
import 'core/widgets/status_chip.dart';
import 'core/widgets/priority_chip.dart';
import 'core/widgets/primary_nav.dart';
import 'core/widgets/home_shell.dart';
import 'core/widgets/empty_state.dart';
import 'features/profile/profile_page.dart';
import 'features/dashboard/dashboard_providers.dart';
import 'core/widgets/kpi_card.dart';
import 'core/widgets/section_card.dart';
import 'core/widgets/skeleton_box.dart';
import 'features/orders/work_order_details_page.dart';
import 'features/notifications/notifications_page.dart';

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
    final baseTextTheme = createTextTheme(context, 'Inter', 'Inter');
    final appTextTheme = AppTypography.textTheme(baseTextTheme);
    final materialTheme = MaterialTheme(appTextTheme);
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
        '/notifications': (_) => const NotificationsPage(),
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
    final profile = ref.watch(myProfileProvider);
    final recent = ref.watch(recentNotificationsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
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
                          // Date/time removed per request
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () => Navigator.pushNamed(context, '/notifications'),
                      icon: const Icon(Icons.notifications_none),
                    ),
                    const SizedBox(width: 4),
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
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: todaysOrders.when(
              data: (items) {
                bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
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
                final todayRelevant = items.where((wo) => effectiveDate(wo) != null).toList();
                todayRelevant.sort((a, b) {
                  final ad = effectiveDate(a);
                  final bd = effectiveDate(b);
                  if (ad == null && bd == null) return 0;
                  if (ad == null) return 1;
                  if (bd == null) return -1;
                  return ad.compareTo(bd);
                });
                final visible = todayRelevant.take(5).toList();
                return SectionCard(
                  title: "Today's orders",
                  leadingIcon: Icons.event_available,
                  filled: true,
                  count: todayRelevant.length,
                  onSeeAll: () => Navigator.pushNamed(context, '/orders'),
                  child: (visible.isEmpty)
                      ? const ListTile(
                          leading: Icon(Icons.assignment_outlined),
                          title: Text('No orders for today'),
                          subtitle: Text('You are all caught up.'),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final wo = visible[i];
                            return RepaintBoundary(
                              child: ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: const Icon(Icons.build_outlined),
                                title: Text(wo.title ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Row(children: [if ((wo.status ?? '').isNotEmpty) StatusChip(wo.status!), const SizedBox(width: 8), Text(wo.priority ?? '-')]),
                                trailing: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => WorkOrderDetailsPage(id: wo.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Start'),
                                ),
                                onTap: () => Navigator.pushNamed(context, '/orders'),
                              ),
                            );
                          },
                        ),
                );
              },
              loading: () => SectionCard(
                title: "Today's orders",
                leadingIcon: Icons.event_available,
                filled: true,
                onSeeAll: () => Navigator.pushNamed(context, '/orders'),
                child: const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
              ),
              error: (e, st) => SectionCard(
                title: "Today's orders",
                leadingIcon: Icons.event_available,
                filled: true,
                onSeeAll: () => Navigator.pushNamed(context, '/orders'),
                child: const ListTile(title: Text("Failed to load today's orders")),
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
                      label: 'Active',
                      value: v['active'] ?? 0,
                      icon: Icons.bolt_outlined,
                      illustrationIcon: Icons.bolt,
                      color: scheme.primary,
                      onTap: () => Navigator.pushNamed(context, '/orders'),
                    ),
                    KpiCard(
                      label: 'In progress',
                      value: v['in_progress'] ?? 0,
                      icon: Icons.autorenew,
                      illustrationIcon: Icons.autorenew,
                      color: scheme.tertiary,
                      onTap: () => Navigator.pushNamed(context, '/orders'),
                    ),
                    KpiCard(
                      label: 'Review',
                      value: v['review'] ?? 0,
                      icon: Icons.fact_check_outlined,
                      illustrationIcon: Icons.fact_check,
                      color: scheme.secondary,
                      onTap: () => Navigator.pushNamed(context, '/orders'),
                    ),
                    KpiCard(
                      label: 'Done',
                      value: v['done'] ?? 0,
                      icon: Icons.task_alt,
                      illustrationIcon: Icons.task_alt,
                      color: scheme.primary,
                      onTap: () => Navigator.pushNamed(context, '/orders'),
                    ),
                  ];
                  return GridView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.2,
                    ),
                    itemBuilder: (context, index) => cards[index],
                  );
                },
                loading: () => GridView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                  ),
                  itemBuilder: (context, index) => const SkeletonBox(height: 64),
                ),
                error: (e, st) => const SizedBox.shrink(),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: recent.when(
              data: (items) {
                final visible = items.take(5).toList();
                return SectionCard(
                  title: 'Recent activity',
                  leadingIcon: Icons.notifications_none,
                  filled: true,
                  count: items.length,
                  actions: [
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.refresh(recentNotificationsProvider),
                    ),
                  ],
                  onSeeAll: () => Navigator.pushNamed(context, '/notifications'),
                  child: visible.isEmpty
                      ? const ListTile(
                          leading: Icon(Icons.notifications_off_outlined),
                          title: Text('No recent activity'),
                          subtitle: Text('You are all caught up.'),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visible.length,
                          separatorBuilder: (_, index) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final n = visible[i];
                            String timeAgo(DateTime dt) {
                              final now = DateTime.now();
                              final diff = now.difference(dt.toLocal());
                              if (diff.inSeconds < 60) return 'just now';
                              if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
                              if (diff.inHours < 24) return '${diff.inHours}h ago';
                              if (diff.inDays == 1) return 'yesterday';
                              if (diff.inDays < 7) return '${diff.inDays}d ago';
                              final weeks = (diff.inDays / 7).floor();
                              if (weeks < 5) return '${weeks}w ago';
                              final months = (diff.inDays / 30).floor();
                              if (months < 12) return '${months}mo ago';
                              final years = (diff.inDays / 365).floor();
                              return '${years}y ago';
                            }
                            return RepaintBoundary(
                              child: ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: const Icon(Icons.notifications_outlined),
                                title: Text(
                                  (n.message ?? n.title ?? 'Activity'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600),
                                ),
                                trailing: Text(timeAgo(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
                                onTap: () => Navigator.pushNamed(context, '/notifications'),
                              ),
                            );
                          },
                        ),
                );
              },
              loading: () => SectionCard(
                title: 'Recent activity',
                leadingIcon: Icons.notifications_none,
                filled: true,
                onSeeAll: () => Navigator.pushNamed(context, '/notifications'),
                child: const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
              ),
              error: (e, st) => SectionCard(
                title: 'Recent activity',
                leadingIcon: Icons.notifications_none,
                filled: true,
                onSeeAll: () => Navigator.pushNamed(context, '/notifications'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Failed to load recent activity'),
                      const SizedBox(height: 4),
                      Text('$e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionCard(
              title: "Today's leaves",
              onSeeAll: () {
                const fixedUid = '9022b441-6257-4d6b-ac9d-7461fa6db6dd';
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeavesPage(userId: fixedUid)),
                );
              },
              child: const _TodaysLeavesSection(userId: '9022b441-6257-4d6b-ac9d-7461fa6db6dd'),
            ),
          ),
          
        ],
      ),
      bottomNavigationBar: showNav ? const PrimaryNavBar(currentIndex: 0) : null,
    );
  }
}

class _TodaysLeavesSection extends StatefulWidget {
  final String userId;
  const _TodaysLeavesSection({required this.userId});

  @override
  State<_TodaysLeavesSection> createState() => _TodaysLeavesSectionState();
}

class _TodaysLeavesSectionState extends State<_TodaysLeavesSection> {
  late Future<List<LeaveRequest>> _future;
  final _repo = LeavesRepository();

  @override
  void initState() {
    super.initState();
    _future = _repo.getTodaysLeavesForUser(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LeaveRequest>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
        }
        final items = List<LeaveRequest>.of(snapshot.data ?? const []);
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
            return RepaintBoundary(
              child: ListTile(
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
                onTap: () {
                  Navigator.pushNamed(context, '/leaves');
                },
              ),
            );
          },
        );
      },
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
  final _scrollController = ScrollController();
  List<WorkOrder> _items = const [];
  String? _nextCursor;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _query = '';
  String _sortKey = 'due'; // 'due' | 'priority' | 'status' | 'title'
  bool _ascending = false; // latest first by default

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_loadingMore || !_hasMore) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _nextCursor = null;
    _hasMore = true;
    _items = const [];
    setState(() => _initialLoading = true);
    await _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    try {
      final page = await repo.getAssignedToMePage(cursor: null, limit: 20);
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _initialLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await repo.getAssignedToMePage(cursor: _nextCursor, limit: 20);
      setState(() {
        // Deduplicate by id when appending
        final existingIds = _items.map((e) => e.id).toSet();
        final newOnes = page.items.where((e) => !existingIds.contains(e.id)).toList();
        _items = List.of(_items)..addAll(newOnes);
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
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
        child: Builder(builder: (context) {
          if (_initialLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          List<WorkOrder> items = List.of(_items);
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
                  if (ad == null && bd == null) {
                    res = 0;
                  } else if (ad == null) {
                    res = 1; // nulls last
                  } else if (bd == null) {
                    res = -1;
                  } else {
                    res = ad.compareTo(bd);
                  }
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
            return ListView.custom(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              childrenDelegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i == items.length) {
                    return _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }
                  final wo = items[i];
                  final isLast = i == items.length - 1;
                  return RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(wo.title ?? 'Untitled'),
                          subtitle: Row(
                            children: [
                              if ((wo.status ?? '').isNotEmpty) StatusChip(wo.status!),
                              const SizedBox(width: 8),
                              PriorityChip(wo.priority),
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
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WorkOrderDetailsPage(id: wo.id),
                              ),
                            );
                          },
                        ),
                        if (!isLast) const Divider(height: 1),
                      ],
                    ),
                  );
                },
                childCount: items.length + (_loadingMore ? 1 : 0),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: true,
              ),
            );
          },),
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
  final String? userId;
  const LeavesPage({super.key, this.showNav = true, this.userId});

  @override
  State<LeavesPage> createState() => _LeavesPageState();
}

class _LeavesPageState extends State<LeavesPage> {
  final repo = LeavesRepository();
  final _scrollController = ScrollController();
  List<LeaveRequest> _items = const [];
  String? _nextCursor;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DateTime? _filterMonth; // month/year
  String? _filterStatus; // approved, pending, rejected

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_loadingMore || !_hasMore) return;
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _nextCursor = null;
    _hasMore = true;
    _items = const [];
    setState(() => _initialLoading = true);
    await _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    try {
      final page = await (
        (widget.userId != null && widget.userId!.isNotEmpty)
            ? repo.getLeavesForUserPage(widget.userId!, cursor: null, limit: 20)
            : repo.getMyLeavesPage(cursor: null, limit: 20)
      );
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _initialLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await (
        (widget.userId != null && widget.userId!.isNotEmpty)
            ? repo.getLeavesForUserPage(widget.userId!, cursor: _nextCursor, limit: 20)
            : repo.getMyLeavesPage(cursor: _nextCursor, limit: 20)
      );
      setState(() {
        final existing = _items.map((e) => e.id).toSet();
        final toAdd = page.items.where((e) => !existing.contains(e.id)).toList();
        _items = List.of(_items)..addAll(toAdd);
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _createLeave() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create Leave coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaves'),
        actions: [
          IconButton(
            tooltip: 'Search / Filter',
            icon: const Icon(Icons.search),
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) {
                  String? localStatus = _filterStatus;
                  DateTime? localMonth = _filterMonth;
                  int? localMonthNum = localMonth?.month;
                  int localYear = (localMonth?.year) ?? DateTime.now().year;
                  return StatefulBuilder(builder: (context, setLocal) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Filter leaves', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String?>(
                                  value: localStatus,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Status'),
                                  items: const [
                                    DropdownMenuItem<String?>(value: null, child: Text('All')),
                                    DropdownMenuItem<String?>(value: 'approved', child: Text('Approved')),
                                    DropdownMenuItem<String?>(value: 'pending', child: Text('Pending')),
                                    DropdownMenuItem<String?>(value: 'rejected', child: Text('Rejected')),
                                  ],
                                  onChanged: (v) => setLocal(() => localStatus = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: localYear,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Year'),
                                  items: () {
                                    final nowY = DateTime.now().year;
                                    final years = List<int>.generate(7, (i) => nowY - 5 + i); // [now-5 .. now+1]
                                    return years
                                        .map((y) => DropdownMenuItem<int>(value: y, child: Text(y.toString())))
                                        .toList();
                                  }(),
                                  onChanged: (v) => setLocal(() => localYear = v ?? DateTime.now().year),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  value: localMonthNum,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Month'),
                                  items: <DropdownMenuItem<int?>>[
                                    const DropdownMenuItem<int?>(value: null, child: Text('All')),
                                    const DropdownMenuItem<int?>(value: 1, child: Text('January')),
                                    const DropdownMenuItem<int?>(value: 2, child: Text('February')),
                                    const DropdownMenuItem<int?>(value: 3, child: Text('March')),
                                    const DropdownMenuItem<int?>(value: 4, child: Text('April')),
                                    const DropdownMenuItem<int?>(value: 5, child: Text('May')),
                                    const DropdownMenuItem<int?>(value: 6, child: Text('June')),
                                    const DropdownMenuItem<int?>(value: 7, child: Text('July')),
                                    const DropdownMenuItem<int?>(value: 8, child: Text('August')),
                                    const DropdownMenuItem<int?>(value: 9, child: Text('September')),
                                    const DropdownMenuItem<int?>(value: 10, child: Text('October')),
                                    const DropdownMenuItem<int?>(value: 11, child: Text('November')),
                                    const DropdownMenuItem<int?>(value: 12, child: Text('December')),
                                  ],
                                  onChanged: (v) => setLocal(() { localMonthNum = v; localMonth = v == null ? null : DateTime(localYear, v, 1); }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () {
                                    setState(() {
                                      _filterMonth = localMonthNum == null ? null : DateTime(localYear, localMonthNum!, 1);
                                      _filterStatus = localStatus;
                                    });
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Apply'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _filterMonth = null;
                                    _filterStatus = null;
                                  });
                                  Navigator.pop(context);
                                },
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  });
                },
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Builder(builder: (context) {
          if (_initialLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          // Filter client-side by selected month (overlap) and status
          final items = List.of(_items).where((lv) {
              final matchesStatus = _filterStatus == null || _filterStatus!.isEmpty || lv.status == _filterStatus;
              final matchesMonth = _filterMonth == null || (() {
                final y = _filterMonth!.year;
                final m = _filterMonth!.month;
                final monthStart = DateTime(y, m, 1);
                final monthEndExclusive = m == 12 ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
                // Overlap if lv.endDate >= monthStart AND lv.startDate < monthEndExclusive
                return !lv.endDate.isBefore(monthStart) && lv.startDate.isBefore(monthEndExclusive);
              })();
              return matchesStatus && matchesMonth;
            }).toList();
            // Sort by most recent start date first (latest on top)
            items.sort((a, b) => b.startDate.compareTo(a.startDate));
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No leaves',
                message: 'No leave requests found. Pull to refresh or create one.',
                actionLabel: 'New leave',
                onAction: _createLeave,
              );
            }
            return ListView.custom(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              childrenDelegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i == items.length) {
                    return _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }
                  final lv = items[i];
                  final start = lv.startDate.toString().split(' ').first;
                  final end = lv.endDate.toString().split(' ').first;
                  final range = '$start → $end';
                  final isLast = i == items.length - 1;
                  return RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(lv.reason?.isNotEmpty == true ? lv.reason! : '(No reason)'),
                          subtitle: Text('${lv.typeKey} • $start → $end'),
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
                        ),
                        if (!isLast) const Divider(height: 1),
                      ],
                    ),
                  );
                },
                childCount: items.length + (_loadingMore ? 1 : 0),
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: true,
              ),
            );
          },),
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
                        const ListTile(title: Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600))),
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
