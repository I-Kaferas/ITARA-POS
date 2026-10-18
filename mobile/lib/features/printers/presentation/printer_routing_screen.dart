import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/print_group.dart';
import '../domain/print_route.dart';
import '../domain/printer.dart';
import 'bloc/printer_routing_bloc.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// UI to define Category / Product / Document → Printer (mobile.md §40).
class PrinterRoutingScreen extends StatelessWidget {
  const PrinterRoutingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PrinterRoutingBloc>()..add(const PrinterRoutingStarted()),
      child: const _PrinterRoutingView(),
    );
  }
}

class _PrinterRoutingView extends StatelessWidget {
  const _PrinterRoutingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Routage imprimantes')),
        actions: [
          IconButton(
            tooltip: tr('Rafraîchir'),
            onPressed: () =>
                context.read<PrinterRoutingBloc>().add(const PrinterRoutingRefreshed()),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: tr('Réinstaller les exemples'),
            onPressed: () => context
                .read<PrinterRoutingBloc>()
                .add(const PrinterRoutingSeedRequested(force: true)),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Règle')),
      ),
      body: BlocBuilder<PrinterRoutingBloc, PrinterRoutingState>(
        builder: (context, state) {
          if (state.isLoading && state.routes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _ExampleBanner(),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  tr(state.errorMessage!),
                  style: AppTypography.text(color: AppColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              _Section(
                title: tr('Catégorie → Imprimante'),
                subtitle: tr('Ex. Drink → Bar Printer'),
                routes: state.categoryRoutes,
                destinationOf: state.describeDestination,
                onEdit: (route) => _openEditor(context, existing: route),
                onDelete: (id) => context
                    .read<PrinterRoutingBloc>()
                    .add(PrinterRoutingDeleted(id)),
              ),
              const SizedBox(height: 16),
              _Section(
                title: tr('Produit → Imprimante'),
                subtitle: tr('Ex. Pizza Margherita → Kitchen Printer'),
                routes: state.productRoutes,
                destinationOf: state.describeDestination,
                onEdit: (route) => _openEditor(context, existing: route),
                onDelete: (id) => context
                    .read<PrinterRoutingBloc>()
                    .add(PrinterRoutingDeleted(id)),
              ),
              const SizedBox(height: 16),
              _Section(
                title: tr('Document → Imprimante'),
                subtitle: tr('Ex. Receipt → Cashier Printer'),
                routes: state.documentRoutes,
                destinationOf: state.describeDestination,
                onEdit: (route) => _openEditor(context, existing: route),
                onDelete: (id) => context
                    .read<PrinterRoutingBloc>()
                    .add(PrinterRoutingDeleted(id)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {PrintRoute? existing}) async {
    final bloc = context.read<PrinterRoutingBloc>();
    final result = await showDialog<PrintRoute>(
      context: context,
      builder: (ctx) => _RouteEditorDialog(
        initial: existing,
        printers: bloc.state.printers,
      ),
    );
    if (result == null || !context.mounted) return;
    bloc.add(PrinterRoutingUpserted(result));
  }
}

class _ExampleBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Routage POS'),
            style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            tr('Drink → Bar · Pizza → Cuisine · Receipt → Caisse'),
            style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            tr('Priorité : Produit > Catégorie > Document'),
            style: AppTypography.text(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.routes,
    required this.destinationOf,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<PrintRoute> routes;
  final String Function(PrintRoute) destinationOf;
  final ValueChanged<PrintRoute> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(title), style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 2),
        Text(tr(subtitle), style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (routes.isEmpty)
          Text(
            tr('Aucune règle'),
            style: AppTypography.text(fontSize: 13, color: AppColors.textMuted),
          )
        else
          ...routes.map(
            (route) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  switch (route.kind) {
                    PrintRouteKind.category => Icons.category_outlined,
                    PrintRouteKind.product => Icons.inventory_2_outlined,
                    PrintRouteKind.document => Icons.description_outlined,
                  },
                  color: AppColors.brandInk,
                ),
                title: Text(tr(route.displayLabel), style: AppTypography.text(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  trf('{0} · {1} · prio {2}''{3}', [route.matchKey, destinationOf(route), route.priority, route.enabled ? '' : ' · désactivé']),
                ),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: tr('Modifier'),
                      onPressed: () => onEdit(route),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                    IconButton(
                      tooltip: tr('Supprimer'),
                      onPressed: () => onDelete(route.id),
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RouteEditorDialog extends StatefulWidget {
  const _RouteEditorDialog({this.initial, required this.printers});

  final PrintRoute? initial;
  final List<Printer> printers;

  @override
  State<_RouteEditorDialog> createState() => _RouteEditorDialogState();
}

class _RouteEditorDialogState extends State<_RouteEditorDialog> {
  late PrintRouteKind _kind;
  late PrintGroup _group;
  late TextEditingController _matchCtrl;
  late TextEditingController _labelCtrl;
  late TextEditingController _priorityCtrl;
  String _printerId = '';
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _kind = initial?.kind ?? PrintRouteKind.category;
    _group = initial?.group ?? PrintGroup.kitchen;
    _matchCtrl = TextEditingController(text: initial?.matchKey ?? '');
    _labelCtrl = TextEditingController(text: initial?.label ?? '');
    _priorityCtrl = TextEditingController(
      text: '${initial?.priority ?? _kind.defaultPriority}',
    );
    _printerId = initial?.printerId ?? '';
    _enabled = initial?.enabled ?? true;
  }

  @override
  void dispose() {
    _matchCtrl.dispose();
    _labelCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(widget.initial == null ? 'Nouvelle règle' : 'Modifier la règle')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PrintRouteKind>(
                value: _kind,
                decoration: InputDecoration(labelText: tr('Type')),
                items: PrintRouteKind.values
                    .map((k) => DropdownMenuItem(value: k, child: Text(tr(k.label))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _kind = value;
                    if (widget.initial == null) {
                      _priorityCtrl.text = '${value.defaultPriority}';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _matchCtrl,
                decoration: InputDecoration(
                  labelText: switch (_kind) {
                    PrintRouteKind.category => 'Catégorie (id ou slug, ex. drink)',
                    PrintRouteKind.product => 'Produit (id ou SKU)',
                    PrintRouteKind.document => 'Document (ex. receipt, kitchen)',
                  },
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PrintGroup>(
                value: _group,
                decoration: InputDecoration(labelText: tr('Groupe imprimante')),
                items: PrintGroup.values
                    .map((g) => DropdownMenuItem(value: g, child: Text(tr(g.label))))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _group = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _printerId.isEmpty ? '' : _printerId,
                decoration: InputDecoration(
                  labelText: tr('Imprimante précise (optionnel)'),
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text(tr('— Groupe uniquement —'))),
                  ...widget.printers.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.name} (${p.group.label})'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _printerId = value ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelCtrl,
                decoration: InputDecoration(
                  labelText: tr('Libellé'),
                  hintText: tr('Drink → Bar Printer'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priorityCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: tr('Priorité (plus bas = plus prioritaire)'),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Activée')),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Annuler'))),
        FilledButton(
          onPressed: () {
            final match = _matchCtrl.text.trim();
            if (match.isEmpty) return;
            Navigator.pop(
              context,
              PrintRoute(
                id: widget.initial?.id ?? const Uuid().v4(),
                kind: _kind,
                matchKey: match,
                group: _group,
                printerId: _printerId,
                enabled: _enabled,
                priority: int.tryParse(_priorityCtrl.text.trim()) ?? _kind.defaultPriority,
                label: _labelCtrl.text.trim(),
              ),
            );
          },
          child: Text(tr('Enregistrer')),
        ),
      ],
    );
  }
}
