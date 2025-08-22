import 'package:flutter/material.dart';
import 'package:mra_cmms/repositories/assets_repository.dart';
import 'package:mra_cmms/features/assets/asset_details_page.dart';
import 'package:mra_cmms/core/widgets/responsive_constraints.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({super.key});

  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final repo = AssetsRepository();
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();

  final List<AssetInfo> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String _query = '';
  static const _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _load(first: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load({bool first = false}) async {
    setState(() {
      if (first) {
        _loading = true;
        _items.clear();
        _hasMore = true;
      }
    });
    try {
      final data = await repo.list(query: _query, limit: _pageSize, offset: 0);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(data);
        _hasMore = data.length == _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final data = await repo.list(query: _query, limit: _pageSize, offset: _items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(data);
        _hasMore = data.length == _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _load(first: true);
  }

  void _onSearchChanged(String v) {
    _query = v.trim();
    // debounce-lite: small delay could be added; keep immediate for simplicity
    _load(first: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assets')),
      body: ResponsiveConstraints(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search assets by name or code',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                child: _loading && _items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final a = _items[index];
                          return ListTile(
                            title: Text(a.name.isEmpty ? '-' : a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${a.assetId} • ${a.locationId ?? '-'}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AssetDetailsPage(id: a.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
