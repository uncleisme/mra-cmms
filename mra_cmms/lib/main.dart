import 'package:flutter/material.dart';
import 'dart:async';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'core/supabase_config.dart';
import 'core/hive_init.dart';
import 'repositories/work_orders_repository.dart';
import 'repositories/leaves_repository.dart';
import 'repositories/profiles_repository.dart';
import 'models/work_order.dart';
import 'models/leave.dart';
import 'models/profile.dart';
import 'core/theme/theme.dart';
import 'core/theme/util.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/typography.dart';
import 'core/utils/string_utils.dart';
import 'core/widgets/app_text_field.dart';
import 'core/widgets/app_button.dart';
import 'core/widgets/status_chip.dart';
import 'core/widgets/priority_chip.dart';
import 'core/widgets/primary_nav.dart';
import 'core/widgets/home_shell.dart';
import 'core/widgets/empty_state.dart';
import 'features/profile/profile_page.dart';
import 'features/dashboard/dashboard_providers.dart';
import 'core/widgets/section_card.dart';
import 'features/orders/work_order_details_page.dart';
import 'features/orders/new_work_order_page.dart';
import 'features/notifications/notifications_page.dart';
import 'features/schedule/my_schedule_page.dart';
import 'core/widgets/responsive_constraints.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Font size options

/// Reusable action buttons for work order approval/rejection
// _WorkOrderActionButtons removed as it is no longer used

// _confirm removed as it is no longer used

class _RequesterName extends StatefulWidget {
  final String userId;
  const _RequesterName({required this.userId});
  @override
  State<_RequesterName> createState() => _RequesterNameState();
}

class _RequesterNameState extends State<_RequesterName> {
  final _profiles = ProfilesRepository();
  Future<String?>? _future;
  @override
  void initState() {
    super.initState();
    _future = () async {
      try {
        final p = await _profiles.getById(widget.userId);
        final name = (p?.fullName ?? '').trim();
        if (name.isNotEmpty) return name;
        final email = (p?.email ?? '').trim();
        return email.isNotEmpty ? email : widget.userId;
      } catch (_) {
        return widget.userId;
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _future,
      builder: (context, snapshot) {
        final text = snapshot.data ?? widget.userId;
        return Text(
          'User: $text',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        );
      },
    );
  }
}

String fmtShortDate(DateTime d) {
  final yy = (d.year % 100).toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/$yy';
}

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
        '/orders/review': (_) =>
            const HomeShell(initialIndex: 1, ordersFilter: 'Review'),
        '/orders/new': (_) => const NewWorkOrderPage(),
        '/leaves': (_) => const HomeShell(initialIndex: 2),
        // '/leaves/approval': (_) => const PendingLeavesApprovalPage(),
        '/settings': (_) => const HomeShell(initialIndex: 3),
        '/profile': (_) => const ProfilePage(),
        '/notifications': (_) => const NotificationsPage(),
        '/schedule': (_) => const MySchedulePage(),
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
        // Invalidate profile provider so dashboard loads correct user
        ProviderScope.containerOf(
          context,
          listen: false,
        ).invalidate(myProfileProvider);
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } on AuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
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
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: passwordController,
                    label: 'Password',
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 chars' : null,
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
              const SnackBar(
                content: Text(
                  'Registered. Please verify if required, then sign in.',
                ),
              ),
            );
            Navigator.pop(context);
          }
        }
      } on AuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
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
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter name' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: emailController,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: passwordController,
                    label: 'Password',
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 chars' : null,
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
    final profile = ref.watch(myProfileProvider);
    // Precompute current time once per build
    final now = DateTime.now();
    // Cache media size to avoid repeated queries (moved into widgets where used)
    // Determine role once for this build
    final isAdmin = profile.maybeWhen(
      data: (p) => ((p?.type ?? '').toLowerCase() == 'admin'),
      orElse: () => false,
    );

    return Scaffold(
      bottomNavigationBar: showNav
          ? const PrimaryNavBar(currentIndex: 0)
          : null,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: ResponsiveConstraints(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gradient header
                DashboardHeader(profile: profile, now: now),

                // Quick actions (admins only)
                if (isAdmin) const QuickActions(),
                const SizedBox(height: 16),
                // Technician entry to My Schedule
                if (!isAdmin) const MyScheduleEntry(),
                const SizedBox(height: 16),
                profile.when(
                  data: (p) {
                    final isAdmin = (p?.type ?? '').toLowerCase() == 'admin';
                    if (isAdmin) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          AdminApprovalSection(),
                          SizedBox(height: 12),
                          // LeavesApprovalSection(),
                        ],
                      );
                    }
                    return TodaysOrdersSection(now: now);
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, st) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                // Middle section cleared (no chart, no recent updates)
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Extracted widgets per dash.md guidance ---

class DashboardHeader extends StatelessWidget {
  final AsyncValue<Profile?> profile;
  final DateTime now;
  const DashboardHeader({super.key, required this.profile, required this.now});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.fromLTRB(
          16,
          w < 400 ? 24.0 : 28.0,
          16,
          w < 400 ? 16.0 : 20.0,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
                      final name = (p?.fullName?.trim().isNotEmpty ?? false)
                          ? p!.fullName!.trim().split(' ').first
                          : 'there';
                      final hour = now.hour;
                      final greeting = hour < 12
                          ? 'Good morning'
                          : hour < 17
                          ? 'Good afternoon'
                          : 'Good evening';
                      return Text(
                        '$greeting, $name',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize:
                                  (Theme.of(
                                        context,
                                      ).textTheme.headlineSmall?.fontSize ??
                                      24) *
                                  (w >= 700 ? 1.1 : 1.0),
                            ),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 20,
                      width: 140,
                      child: LinearProgressIndicator(),
                    ),
                    error: (e, st) => Text(
                      'Welcome',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
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
                  borderRadius: BorderRadius.circular(28),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? const Icon(
                            Icons.person_outline,
                            size: 22,
                            color: Colors.black87,
                          )
                        : null,
                  ),
                );
              },
              loading: () => const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person_outline,
                  size: 22,
                  color: Colors.black87,
                ),
              ),
              error: (e, st) => const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person_outline,
                  size: 22,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isCompact = w < 420;
        if (isCompact) {
          return RepaintBoundary(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/orders/new'),
                    icon: const Icon(Icons.add_task, size: 26),
                    label: const Text('New Orders'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 22,
                        horizontal: 24,
                      ),
                      textStyle: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RepaintBoundary(
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/orders/new'),
                  icon: const Icon(Icons.add_task, size: 26),
                  label: const Text('New Orders'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 22,
                      horizontal: 24,
                    ),
                    textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MyScheduleEntry extends StatelessWidget {
  const MyScheduleEntry({super.key});
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'My schedule',
      onSeeAll: () => Navigator.pushNamed(context, '/schedule'),
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: const Text('Open My Schedule'),
        subtitle: const Text('View today and this week'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.pushNamed(context, '/schedule'),
      ),
    );
  }
}

class AdminApprovalSection extends ConsumerWidget {
  const AdminApprovalSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleStyleBold = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    final pending = ref.watch(pendingReviewsProvider);
    return pending.when(
      data: (items) => RepaintBoundary(
        child: SectionCard(
          title: 'Work Order Approval',
          filled: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          square: true,
          outlined: true,
          margin: EdgeInsets.zero,
          maxWidth: double.infinity,
          titleTextStyle: titleStyleBold,
          count: items.length,
          // onSeeAll: removed WorkOrdersReviewPage
          child: ListTile(
            leading: const Icon(Icons.inbox_outlined),
            title: Text('${items.length} work order(s) pending'),
            subtitle: const Text('Work Order Approval'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.pushNamed(context, '/orders/review'),
          ),
        ),
      ),
      loading: () => RepaintBoundary(
        child: SectionCard(
          title: 'Needs approval',
          filled: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          square: true,
          outlined: true,
          margin: EdgeInsets.zero,
          maxWidth: double.infinity,
          titleTextStyle: titleStyleBold,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
        ),
      ),
      error: (e, st) => RepaintBoundary(
        child: SectionCard(
          title: 'Needs approval',
          filled: false,
          backgroundColor: Theme.of(context).colorScheme.surface,
          square: true,
          outlined: true,
          margin: EdgeInsets.zero,
          maxWidth: double.infinity,
          titleTextStyle: titleStyleBold,
          child: const ListTile(title: Text('Failed to load pending reviews')),
        ),
      ),
    );
  }
}

// Page to list all work orders with status 'Review' for admin approval
// WorkOrdersReviewPage and all references removed

// Processing moved out of build
List<(WorkOrder, DateTime?)> computeTodayRelevant(
  List<WorkOrder> items,
  DateTime now,
) {
  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool isToday(DateTime? d) {
    if (d == null) return false;
    final local = d.toLocal();
    return isSameDay(local, now);
  }

  DateTime? eff(WorkOrder wo) {
    final status = (wo.status ?? '').toLowerCase();
    final dueToday = isToday(wo.dueDate);
    final completed =
        status == 'completed' || status == 'done' || status == 'closed';
    final nextToday = completed && isToday(wo.nextScheduledDate);
    if (dueToday) return wo.dueDate?.toLocal();
    if (nextToday) return wo.nextScheduledDate?.toLocal();
    return null;
  }

  final withEff = <(WorkOrder, DateTime?)>[
    for (final wo in items) (wo, eff(wo)),
  ];
  final todayRelevant = withEff.where((e) => e.$2 != null).toList();
  todayRelevant.sort((a, b) => a.$2!.compareTo(b.$2!));
  return todayRelevant;
}

class TodaysOrdersSection extends ConsumerWidget {
  final DateTime now;
  const TodaysOrdersSection({super.key, required this.now});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysOrders = ref.watch(todaysOrdersProvider);
    final w = MediaQuery.sizeOf(context).width;
    return todaysOrders.when(
      data: (items) {
        final todayRelevant = computeTodayRelevant(items, now);
        final visible = todayRelevant.take(5).toList();
        if (visible.isEmpty) {
          return SectionCard(
            title: "Today's orders",
            filled: true,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            padding: EdgeInsets.fromLTRB(
              w < 360 ? 8 : 12,
              w < 360 ? 10 : 14,
              w < 360 ? 8 : 12,
              w < 360 ? 8 : 12,
            ),
            titleTextStyle: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            count: todayRelevant.length,
            onSeeAll: () => Navigator.pushNamed(context, '/orders'),
            child: const ListTile(
              leading: Icon(Icons.inbox_outlined),
              title: Text('No orders for today'),
              subtitle: Text('You are all caught up.'),
            ),
          );
        }
        final count = visible.length.clamp(0, 3);
        return SectionCard(
          title: "Today's orders",
          filled: true,
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          padding: EdgeInsets.fromLTRB(
            w < 360 ? 8 : 12,
            w < 360 ? 10 : 14,
            w < 360 ? 8 : 12,
            w < 360 ? 8 : 12,
          ),
          titleTextStyle: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          count: todayRelevant.length,
          onSeeAll: () => Navigator.pushNamed(context, '/orders'),
          child: Column(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const Divider(height: 1),
                Builder(
                  builder: (context) {
                    final wo = visible[i].$1;
                    final titleStr = (() {
                      final raw = (wo.title ?? 'Untitled').trim();
                      final safe = raw.isEmpty ? 'Untitled' : raw;
                      return titleCase(safe);
                    })();
                    return ListTile(
                      leading: const Icon(Icons.work_outline),
                      title: Text(
                        titleStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if ((wo.status ?? '').isNotEmpty)
                            StatusChip(wo.status!),
                          PriorityChip(wo.priority),
                        ],
                      ),
                      visualDensity: w < 360
                          ? const VisualDensity(vertical: -2)
                          : VisualDensity.standard,
                      trailing: FilledButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkOrderDetailsPage(id: wo.id),
                            ),
                          );
                          // Refresh dashboard providers to reflect any status changes
                          ref.invalidate(todaysOrdersProvider);
                          ref.invalidate(kpisProvider);
                          ref.invalidate(recentNotificationsProvider);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
      loading: () => SectionCard(
        title: "Today's orders",
        filled: true,
        backgroundColor: const Color(0xFF08234F),
        foregroundColor: Colors.white,
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize:
              (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * 1.3,
        ),
        onSeeAll: () => Navigator.pushNamed(context, '/orders'),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (e, st) => SectionCard(
        title: "Today's orders",
        filled: true,
        backgroundColor: const Color(0xFF08234F),
        foregroundColor: Colors.white,
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize:
              (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * 1.3,
        ),
        onSeeAll: () => Navigator.pushNamed(context, '/orders'),
        child: const ListTile(title: Text("Failed to load today's orders")),
      ),
    );
    // ...existing code...
  }
}

class OrdersPage extends StatefulWidget {
  final bool showNav;
  final String? initialFilter;
  const OrdersPage({super.key, this.showNav = true, this.initialFilter});

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
  final String _sortKey = 'due'; // 'due' | 'priority' | 'status' | 'title'
  final bool _ascending = false; // latest first by default
  String? _statusFilter; // active | in_progress | review | done
  String? _datePreset; // null=all time | today | week | month | next_month
  bool _adminScope = true; // always true for admin, fetch all

  @override
  void initState() {
    _statusFilter = widget.initialFilter?.toLowerCase() ?? '';
    _adminScope = true;
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
      if (_adminScope) {
        final status = (_statusFilter ?? 'review');
        final page = await repo.getByStatusPage(
          status: status,
          cursor: null,
          limit: 20,
        );
        setState(() {
          _items = page.items;
          _nextCursor = page.nextCursor;
          _hasMore = page.nextCursor != null;
          _initialLoading = false;
        });
        return;
      }

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
      if (_adminScope) {
        final status = (_statusFilter ?? 'review');
        final page = await repo.getByStatusPage(
          status: status,
          cursor: _nextCursor,
          limit: 20,
        );
        setState(() {
          final existingIds = _items.map((e) => e.id).toSet();
          final newOnes = page.items
              .where((e) => !existingIds.contains(e.id))
              .toList();
          _items = List.of(_items)..addAll(newOnes);
          _nextCursor = page.nextCursor;
          _hasMore = page.nextCursor != null;
          _loadingMore = false;
        });
        return;
      }

      final page = await repo.getAssignedToMePage(
        cursor: _nextCursor,
        limit: 20,
      );
      setState(() {
        // Deduplicate by id when appending
        final existingIds = _items.map((e) => e.id).toSet();
        final newOnes = page.items
            .where((e) => !existingIds.contains(e.id))
            .toList();
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Create Order coming soon')));
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
              const Text(
                'Search orders',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
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

  // Sort UI moved into status chips; modal sort removed per new design.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Status chips (only All, Active, Review, Done)
                        ChoiceChip(
                          label: const Text('All'),
                          selected:
                              _statusFilter == null || _statusFilter == '',
                          onSelected: (_) {
                            setState(() => _statusFilter = '');
                            _refresh();
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Active'),
                          selected: _statusFilter == 'active',
                          onSelected: (v) {
                            setState(() => _statusFilter = v ? 'active' : '');
                            _refresh();
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Review'),
                          selected: _statusFilter == 'review',
                          onSelected: (v) {
                            setState(() => _statusFilter = v ? 'review' : '');
                            _refresh();
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Done'),
                          selected: _statusFilter == 'done',
                          onSelected: (v) {
                            setState(() => _statusFilter = v ? 'done' : '');
                            _refresh();
                          },
                        ),
                        const SizedBox(width: 12),
                        // Date preset chips
                        // Removed 'All time' filter
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: _datePreset == 'today',
                          onSelected: (v) =>
                              setState(() => _datePreset = v ? 'today' : null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('This week'),
                          selected: _datePreset == 'week',
                          onSelected: (v) =>
                              setState(() => _datePreset = v ? 'week' : null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('This month'),
                          selected: _datePreset == 'month',
                          onSelected: (v) =>
                              setState(() => _datePreset = v ? 'month' : null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Next month'),
                          selected: _datePreset == 'next_month',
                          onSelected: (v) => setState(
                            () => _datePreset = v ? 'next_month' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Builder(
          builder: (context) {
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
            // Filter by selected status chip
            if (_statusFilter != null && _statusFilter!.isNotEmpty) {
              String norm(String? v) =>
                  (v ?? '').toLowerCase().replaceAll('_', ' ');
              final target = norm(_statusFilter).trim();
              items = items.where((wo) {
                final s = norm(wo.status).trim();
                if (target == 'active') {
                  // active = active OR in progress
                  return s == 'active' || s == 'in progress';
                }
                return s == target;
              }).toList();
            }
            // Filter by date preset using dueDate or nextScheduledDate
            if (_datePreset != null) {
              final now = DateTime.now();
              late DateTime start;
              late DateTime end; // exclusive
              switch (_datePreset) {
                case 'today':
                  start = DateTime(now.year, now.month, now.day);
                  end = start.add(const Duration(days: 1));
                  break;
                case 'week':
                  final weekday = now.weekday; // Mon=1..Sun=7
                  start = DateTime(
                    now.year,
                    now.month,
                    now.day,
                  ).subtract(Duration(days: weekday - 1));
                  end = start.add(const Duration(days: 7));
                  break;
                case 'month':
                  start = DateTime(now.year, now.month, 1);
                  end = (now.month == 12)
                      ? DateTime(now.year + 1, 1, 1)
                      : DateTime(now.year, now.month + 1, 1);
                  break;
                case 'next_month':
                  final isDec = now.month == 12;
                  final y = isDec ? now.year + 1 : now.year;
                  final m = isDec ? 1 : now.month + 1;
                  start = DateTime(y, m, 1);
                  end = (m == 12)
                      ? DateTime(y + 1, 1, 1)
                      : DateTime(y, m + 1, 1);
                  break;
                default:
                  start = DateTime.fromMillisecondsSinceEpoch(0);
                  end = DateTime.fromMillisecondsSinceEpoch(0);
              }
              bool inRange(DateTime d) => !d.isBefore(start) && d.isBefore(end);
              items = items.where((wo) {
                final due = wo.dueDate;
                final next = wo.nextScheduledDate;
                if (due != null && inRange(due)) return true;
                if (next != null && inRange(next)) return true;
                return false;
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
                  res = priorityRank(
                    a.priority,
                  ).compareTo(priorityRank(b.priority));
                  break;
                case 'status':
                  res = (a.status ?? '').toLowerCase().compareTo(
                    (b.status ?? '').toLowerCase(),
                  );
                  break;
                case 'title':
                  res = (a.title ?? '').toLowerCase().compareTo(
                    (b.title ?? '').toLowerCase(),
                  );
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
            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final compact = w < 380;
                final titleStyle = Theme.of(context).textTheme.titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize:
                          (Theme.of(context).textTheme.titleMedium?.fontSize ??
                              16) *
                          (w >= 700 ? 1.15 : 1.0),
                    );
                return ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount:
                      items.length + ((_hasMore || _loadingMore) ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final wo = items[i];
                    String fmt(DateTime d) {
                      final yy = (d.year % 100).toString().padLeft(2, '0');
                      final dd = d.day.toString().padLeft(2, '0');
                      final mm = d.month.toString().padLeft(2, '0');
                      return '$dd/$mm/$yy';
                    }

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: compact ? 6 : 8,
                      ),
                      child: Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WorkOrderDetailsPage(id: wo.id),
                              ),
                            );
                            if (!mounted) return;
                            _refresh();
                          },
                          child: Padding(
                            padding: EdgeInsets.all(compact ? 12 : 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (() {
                                          final raw = (wo.title ?? 'Untitled')
                                              .trim();
                                          final safe = raw.isEmpty
                                              ? 'Untitled'
                                              : raw;
                                          return titleCase(safe);
                                        })(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: titleStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if ((wo.status ?? '').isNotEmpty)
                                            StatusChip(wo.status!),
                                          PriorityChip(wo.priority),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Due',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      wo.dueDate == null
                                          ? ''
                                          : fmt(wo.dueDate!),
                                    ),
                                    const SizedBox(height: 6),
                                    FilledButton.tonalIcon(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                WorkOrderDetailsPage(id: wo.id),
                                          ),
                                        );
                                        if (!mounted) return;
                                        _refresh();
                                      },
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: const Text('View'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
      bottomNavigationBar: widget.showNav
          ? const PrimaryNavBar(currentIndex: 1)
          : null,
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
  String? _statusFilter; // approved, pending, rejected
  String? _datePreset; // null=all time | today | week | month | next_month
  String _query = '';

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
      final future = (widget.userId != null && widget.userId!.isNotEmpty)
          ? repo.getLeavesForUserPage(widget.userId!, cursor: null, limit: 20)
          : repo.getMyLeavesPage(cursor: null, limit: 20);
      final page = await future.timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _initialLoading = false;
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading leaves took too long. Please try again.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load leaves: $e')));
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final future = (widget.userId != null && widget.userId!.isNotEmpty)
          ? repo.getLeavesForUserPage(
              widget.userId!,
              cursor: _nextCursor,
              limit: 20,
            )
          : repo.getMyLeavesPage(cursor: _nextCursor, limit: 20);
      final page = await future.timeout(const Duration(seconds: 12));
      setState(() {
        final existing = _items.map((e) => e.id).toSet();
        final toAdd = page.items
            .where((e) => !existing.contains(e.id))
            .toList();
        _items = List.of(_items)..addAll(toAdd);
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _loadingMore = false;
      });
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading more leaves timed out.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load more leaves: $e')));
    }
  }

  void _createLeave() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Create Leave coming soon')));
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
              const Text(
                'Search leaves',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Type, status, or reason',
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
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text('Leaves'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Status chips (limit to Pending, Approved, Rejected)
                        ChoiceChip(
                          label: const Text('Pending'),
                          selected: _statusFilter == 'pending',
                          onSelected: (v) => setState(
                            () => _statusFilter = v ? 'pending' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Approved'),
                          selected: _statusFilter == 'approved',
                          onSelected: (v) => setState(
                            () => _statusFilter = v ? 'approved' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Rejected'),
                          selected: _statusFilter == 'rejected',
                          onSelected: (v) => setState(
                            () => _statusFilter = v ? 'rejected' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date preset chips (removed 'All time')
                        ChoiceChip(
                          label: const Text('Today'),
                          selected: _datePreset == 'today',
                          onSelected: (v) =>
                              setState(() => _datePreset = v ? 'today' : null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('This week'),
                          selected: _datePreset == 'week',
                          onSelected: (v) =>
                              setState(() => _datePreset = v ? 'week' : null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('This month'),
                          selected: _datePreset == 'month',
                          onSelected: (v) =>
                              setState(() => _datePreset = v ? 'month' : null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Next month'),
                          selected: _datePreset == 'next_month',
                          onSelected: (v) => setState(
                            () => _datePreset = v ? 'next_month' : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Builder(
          builder: (context) {
            if (_initialLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            // Filter client-side by query, selected date preset (overlap) and status
            final items = List.of(_items).where((lv) {
              final matchesQuery = () {
                if (_query.isEmpty) return true;
                final q = _query.toLowerCase();
                final type = (lv.typeKey).toLowerCase();
                final status = (lv.status).toLowerCase();
                final reason = (lv.reason ?? '').toLowerCase();
                return type.contains(q) ||
                    status.contains(q) ||
                    reason.contains(q);
              }();
              final matchesStatus =
                  _statusFilter == null ||
                  _statusFilter!.isEmpty ||
                  lv.status == _statusFilter;
              final matchesRange = () {
                if (_datePreset == null) return true; // all time
                DateTime now = DateTime.now();
                DateTime start;
                DateTime end; // exclusive
                if (_datePreset == 'today') {
                  start = DateTime(now.year, now.month, now.day);
                  end = start.add(const Duration(days: 1));
                } else if (_datePreset == 'week') {
                  // Start of week: Monday
                  final weekday = now.weekday; // Mon=1..Sun=7
                  start = DateTime(
                    now.year,
                    now.month,
                    now.day,
                  ).subtract(Duration(days: weekday - 1));
                  end = start.add(const Duration(days: 7));
                } else if (_datePreset == 'month') {
                  start = DateTime(now.year, now.month, 1);
                  end = (now.month == 12)
                      ? DateTime(now.year + 1, 1, 1)
                      : DateTime(now.year, now.month + 1, 1);
                } else if (_datePreset == 'next_month') {
                  final isDec = now.month == 12;
                  final y = isDec ? now.year + 1 : now.year;
                  final m = isDec ? 1 : now.month + 1;
                  start = DateTime(y, m, 1);
                  end = (m == 12)
                      ? DateTime(y + 1, 1, 1)
                      : DateTime(y, m + 1, 1);
                } else {
                  return true;
                }
                // Overlap if lv.endDate >= start AND lv.startDate < end
                return !lv.endDate.isBefore(start) &&
                    lv.startDate.isBefore(end);
              }();
              return matchesQuery && matchesStatus && matchesRange;
            }).toList();
            // Sort: by start date (desc)
            items.sort((a, b) => b.startDate.compareTo(a.startDate));
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No leaves',
                message:
                    'No leave requests found. Pull to refresh or create one.',
                actionLabel: 'New leave',
                onAction: _createLeave,
              );
            }
            Color statusBg(String s, BuildContext c) {
              final cs = Theme.of(c).colorScheme;
              switch (s.toLowerCase()) {
                case 'approved':
                  return cs.secondaryContainer;
                case 'rejected':
                  return cs.errorContainer;
                case 'pending':
                default:
                  return cs.tertiaryContainer;
              }
            }

            Color statusFg(String s, BuildContext c) {
              final cs = Theme.of(c).colorScheme;
              switch (s.toLowerCase()) {
                case 'approved':
                  return cs.onSecondaryContainer;
                case 'rejected':
                  return cs.onErrorContainer;
                case 'pending':
                default:
                  return cs.onTertiaryContainer;
              }
            }

            String cap(String s) {
              final t = s.trim();
              if (t.isEmpty) return t;
              return t[0].toUpperCase() + t.substring(1).toLowerCase();
            }

            String fmt(DateTime d) {
              final yy = (d.year % 100).toString().padLeft(2, '0');
              final dd = d.day.toString().padLeft(2, '0');
              final mm = d.month.toString().padLeft(2, '0');
              return '$dd/$mm/$yy';
            }

            return LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final pad = w < 380 ? 12.0 : 16.0;
                final titleSize =
                    (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) *
                    (w >= 700 ? 1.05 : 1.0);
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  itemCount: items.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      return _loadingMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox.shrink();
                    }
                    final lv = items[i];
                    final start = fmt(lv.startDate);
                    final end = fmt(lv.endDate);
                    final totalDays = (() {
                      final d =
                          lv.endDate.difference(lv.startDate).inDays +
                          1; // inclusive
                      return d < 1 ? 1 : d;
                    })();
                    final bg = statusBg(lv.status, context);
                    final fg = statusFg(lv.status, context);
                    return Padding(
                      padding: EdgeInsets.fromLTRB(12, i == 0 ? 12 : 6, 12, 6),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: EdgeInsets.all(pad),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.beach_access_outlined),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            cap(lv.typeKey),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: titleSize,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bg,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            cap(lv.status),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: fg,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '$start → $end  ·  $totalDays ${totalDays == 1 ? 'day' : 'days'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
      bottomNavigationBar: widget.showNav
          ? const PrimaryNavBar(currentIndex: 2)
          : null,
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, this.showNav = true});
  final bool showNav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    String modeLabel(ThemeMode m) => m == ThemeMode.light
        ? 'Light'
        : m == ThemeMode.dark
        ? 'Dark'
        : 'System';
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Appearance',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
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
                  ThemeMode tempValue = mode;
                  return StatefulBuilder(
                    builder: (context, setState) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListTile(
                              title: Text(
                                'Theme',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('System'),
                              value: ThemeMode.system,
                              groupValue: tempValue,
                              onChanged: (val) =>
                                  setState(() => tempValue = val!),
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('Light'),
                              value: ThemeMode.light,
                              groupValue: tempValue,
                              onChanged: (val) =>
                                  setState(() => tempValue = val!),
                            ),
                            RadioListTile<ThemeMode>(
                              title: const Text('Dark'),
                              value: ThemeMode.dark,
                              groupValue: tempValue,
                              onChanged: (val) =>
                                  setState(() => tempValue = val!),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, tempValue),
                                child: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
              if (picked != null) controller.setMode(picked);
            },
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Account',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('Photo, name, and details'),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
          // Session section and sign out removed for minimal settings UI
        ],
      ),
      bottomNavigationBar: showNav
          ? const PrimaryNavBar(currentIndex: 0)
          : null,
    );
  }
}

// ProfilePage moved to features/profile/profile_page.dart
