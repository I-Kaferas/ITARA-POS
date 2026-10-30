import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/local/local_database.dart';
import '../data/local_search.dart';
import '../domain/search_hit.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _query = TextEditingController();
  List<SearchHit> _hits = const [];
  bool _loading = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    try {
      final db = await LocalDatabase.instance.database;
      final hits = await LocalSearch.query(db, value);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _open(SearchHit hit) {
    switch (hit.kind) {
      case SearchKind.product:
        context.go(AppRoutes.stock);
      case SearchKind.sale:
        context.go(AppRoutes.saleDetail(hit.id));
      case SearchKind.customer:
        context.go(AppRoutes.customerAccount);
      case SearchKind.order:
      case SearchKind.table:
        context.go(AppRoutes.reservations);
      case SearchKind.supplier:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <SearchKind, List<SearchHit>>{};
    for (final hit in _hits) {
      groups.putIfAbsent(hit.kind, () => []).add(hit);
    }
    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: tr('Produits, ventes, clients, tables…'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _query.text.trim().length < 2
                    ? Center(child: Text(tr('Saisissez au moins 2 caractères.')))
                    : _hits.isEmpty
                        ? Center(child: Text(tr('Aucun résultat local.')))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                            children: [
                              for (final kind in SearchKind.values)
                                if (groups[kind]?.isNotEmpty == true) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                                    child: Text(
                                      tr(kind.label),
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  for (final hit in groups[kind]!)
                                    Card(
                                      child: ListTile(
                                        title: Text(hit.title),
                                        subtitle: Text(hit.subtitle.isEmpty ? hit.id : hit.subtitle),
                                        onTap: () => _open(hit),
                                      ),
                                    ),
                                ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
