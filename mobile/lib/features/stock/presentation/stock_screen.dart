import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../sync/sync_engine.dart';
import '../../pos/domain/pos_models.dart';
import '../../pos/presentation/widgets/pos_ui.dart';

/// Stock local léger pour navigation smartphone §18.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<PosProduct> _products = const [];
  bool _loading = true;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await SyncEngine.instance.cachedCatalog();
      if (!mounted) return;
      setState(() {
        _products = catalog?.products ?? const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sync() async {
    setState(() => _loading = true);
    await SyncEngine.instance.downloadStock();
    await _load();
  }

  List<PosProduct> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return ColoredBox(
      color: AppColors.canvas,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Synchroniser',
                  onPressed: _loading ? null : _sync,
                  icon: const Icon(Icons.sync),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: TextButton(
                          onPressed: _load,
                          child: Text('Erreur · Réessayer\n$_error'),
                        ),
                      )
                    : items.isEmpty
                        ? Center(
                            child: Text(
                              'Aucun stock local. Synchronisez le catalogue.',
                              style: PosUi.body(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                            itemCount: items.length,
                            cacheExtent: 400,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final p = items[index];
                              final qty = p.quantityOnHand ?? 0;
                              final threshold = p.lowStockThreshold ?? 0;
                              final low = threshold > 0 && qty <= threshold;
                              return Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                child: ListTile(
                                  minVerticalPadding: 12,
                                  title: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.ibmPlexSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    p.stockDisplay?.isNotEmpty == true
                                        ? p.stockDisplay!
                                        : (p.sku.isEmpty ? '—' : p.sku),
                                    style: PosUi.caption(),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$qty',
                                        style: GoogleFonts.ibmPlexMono(
                                          fontWeight: FontWeight.w700,
                                          color: low
                                              ? AppColors.danger
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        MoneyFormatter.format(p.price),
                                        style: PosUi.caption(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
