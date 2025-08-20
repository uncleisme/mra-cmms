import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../repositories/notifications_repository.dart';
import '../../models/activity_notification.dart';
import 'dart:async';

// Top-level helpers (pure) so UI building widgets can reuse them without accessing State
String _timeAgo(DateTime dt, {DateTime? now}) {
  final nowDt = now ?? DateTime.now();
  final diff = nowDt.difference(dt.toLocal());
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

String _dateHeader(DateTime dt) {
  final now = DateTime.now();
  final d = DateTime(dt.year, dt.month, dt.day);
  final today = DateTime(now.year, now.month, now.day);
  final diffDays = today.difference(d).inDays;
  if (diffDays == 0) return 'Today';
  if (diffDays == 1) return 'Yesterday';
  return '${_monthName(d.month)} ${d.day}, ${d.year}';
}

String _monthName(int m) {
  const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return names[m - 1];
}

(IconData, Color, Color) _visuals(ThemeData theme, String? module, String? action) {
  final scheme = theme.colorScheme;
  final m = (module ?? '').toLowerCase();
  final a = (action ?? '').toLowerCase();
  if (a == 'rejected' || a == 'error' || a == 'failed') {
    return (Icons.error_outline, scheme.errorContainer, scheme.onErrorContainer);
  }
  if (a == 'approved' || a == 'completed') {
    return (Icons.task_alt, scheme.primaryContainer, scheme.onPrimaryContainer);
  }
  if (m.contains('leave')) {
    return (Icons.event_outlined, scheme.secondaryContainer, scheme.onSecondaryContainer);
  }
  if (m.contains('work order') || m.contains('work_orders') || m.contains('orders')) {
    return (Icons.build_outlined, scheme.primaryContainer, scheme.onPrimaryContainer);
  }
  if (m.contains('profile') || m.contains('user')) {
    return (Icons.person_outline, scheme.tertiaryContainer, scheme.onTertiaryContainer);
  }
  return (Icons.notifications_active_outlined, scheme.secondaryContainer, scheme.onSecondaryContainer);
}

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final _repo = NotificationsRepository();
  List<ActivityNotification> _items = const [];
  _Filter _filter = _Filter.all;
  List<Object> _rows = const [];
  DateTime _now = DateTime.now();
  Timer? _ticker;
  // Pagination state
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DateTime? _nextCursor; // created_at of the last item for keyset
  final ScrollController _scrollController = ScrollController();

  Future<void> _loadFirstPage() async {
    try {
      const pageSize = 30;
      final data = await _repo.getForCurrentUserPage(limit: pageSize);
      if (!mounted) return;
      setState(() {
        _items = data;
        _hasMore = data.length == pageSize;
        _nextCursor = data.isNotEmpty ? data.last.createdAt : null;
        _initialLoading = false;
        _recomputeRows();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load notifications: $e')));
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      const pageSize = 30;
      final data = await _repo.getForCurrentUserPage(limit: pageSize, before: _nextCursor);
      if (!mounted) return;
      setState(() {
        // Deduplicate by id when appending
        final existingIds = _items.map((e) => e.id).toSet();
        final toAdd = data.where((e) => !existingIds.contains(e.id)).toList();
        _items = List.of(_items)..addAll(toAdd);
        _hasMore = data.length == pageSize;
        _nextCursor = data.isNotEmpty ? data.last.createdAt : _nextCursor;
        _recomputeRows();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load more: $e')));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      _now = DateTime.now();
      if (mounted) setState(() {});
    });
    _scrollController.addListener(() {
      if (!_hasMore || _loadingMore) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 400) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<ActivityNotification> get _filteredItems {
    if (_filter == _Filter.unread) {
      return _items.where((e) => e.isRead == false).toList();
    }
    return _items;
  }

  void _recomputeRows() {
    final items = _filteredItems;
    final List<Object> rows = [];
    String? currentHeader;
    for (final n in items) {
      final hdr = _dateHeader(n.createdAt);
      if (hdr != currentHeader) {
        currentHeader = hdr;
        rows.add(hdr);
      }
      rows.add(n);
    }
    _rows = rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await _repo.markAllReadForCurrentUser();
              await _loadFirstPage();
            },
            child: const Text('Mark all read'),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _initialLoading = true;
            _hasMore = true;
            _nextCursor = null;
            _items = const [];
            _rows = const [];
          });
          await _loadFirstPage();
        },
        child: _initialLoading
            ? const Center(child: CircularProgressIndicator())
            : (_filteredItems.isEmpty
                ? const Center(child: Text('No notifications'))
                : Column(
                    children: [
                      _FilterChipsRow(
                        selected: _filter,
                        onChanged: (f) {
                          setState(() {
                            _filter = f;
                            _recomputeRows();
                          });
                        },
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.custom(
                          controller: _scrollController,
                          cacheExtent: 800,
                          childrenDelegate: SliverChildBuilderDelegate(
                            (context, i) {
                              if (i == _rows.length) {
                                return _loadingMore ? const _LoadingMoreIndicator() : const SizedBox.shrink();
                              }
                              final row = _rows[i];
                              if (row is String) {
                                return _DateHeaderLabel(text: row);
                              }
                              final n = row as ActivityNotification;

                              final bool showDivider = () {
                                final isLast = i == _rows.length - 1;
                                if (isLast) return _loadingMore; // hide if loading row follows
                                final next = _rows[i + 1];
                                return next is! String;
                              }();

                              return _NotificationRow(
                                n: n,
                                now: _now,
                                onTap: () async {
                                  if (!n.isRead) {
                                    await _repo.markRead(n.id);
                                    setState(() {
                                      final idx = _items.indexWhere((e) => e.id == n.id);
                                      if (idx != -1) {
                                        _items[idx] = ActivityNotification(
                                          id: _items[idx].id,
                                          title: _items[idx].title,
                                          message: _items[idx].message,
                                          module: _items[idx].module,
                                          action: _items[idx].action,
                                          createdAt: _items[idx].createdAt,
                                          isRead: true,
                                        );
                                      }
                                      _recomputeRows();
                                    });
                                  }
                                },
                                showDivider: showDivider,
                              );
                            },
                            childCount: _rows.length + (_loadingMore ? 1 : 0),
                            addAutomaticKeepAlives: false,
                            addRepaintBoundaries: true,
                            addSemanticIndexes: true,
                          ),
                        ),
                      ),
                    ],
                  )),
      ),
    );
  }
}

enum _Filter { all, unread }

// UI components
class _FilterChipsRow extends StatelessWidget {
  final _Filter selected;
  final ValueChanged<_Filter> onChanged;
  const _FilterChipsRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == _Filter.all,
            onSelected: (v) => v ? onChanged(_Filter.all) : null,
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Unread'),
            selected: selected == _Filter.unread,
            onSelected: (v) => v ? onChanged(_Filter.unread) : null,
          ),
        ],
      ),
    );
  }
}

class _DateHeaderLabel extends StatelessWidget {
  final String text;
  const _DateHeaderLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final ActivityNotification n;
  final DateTime now;
  final VoidCallback onTap;
  final bool showDivider;
  const _NotificationRow({required this.n, required this.now, required this.onTap, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (iconData, bg, fg) = _visuals(theme, n.module, n.action);
    final messageText = (n.message ?? '').trim();
    final secondaryText = () {
      final mod = (n.module ?? '').trim();
      final act = (n.action ?? '').trim();
      if (mod.isNotEmpty && act.isNotEmpty) return '$mod • $act';
      if (mod.isNotEmpty) return mod;
      return '';
    }();
    final primaryStyle = n.isRead
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Icon(iconData, color: fg),
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
                                messageText.isNotEmpty ? messageText : (n.title ?? 'Notification'),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: primaryStyle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_timeAgo(n.createdAt, now: now),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ),
                        if (secondaryText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showDivider) const Divider(height: 1),
        ],
      ),
    );
  }
}
