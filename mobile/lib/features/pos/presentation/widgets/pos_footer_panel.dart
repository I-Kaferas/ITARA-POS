import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../receipt/services/kitchen_ticket_service.dart';
import '../../data/pos_api_service.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_cart_engine.dart';
import 'pos_payment_dialog.dart';
import 'pos_ui.dart';

class PosFooterPanel extends StatelessWidget {
  const PosFooterPanel({
    super.key,
    required this.cart,
    required this.api,
    required this.onHold,
    required this.onNewSale,
    required this.onRetrieve,
    required this.onSplit,
    required this.onCancel,
    required this.onPayment,
    this.requestPayment = false,
    this.onPaymentRequestHandled,
  });

  final PosCartEngine cart;
  final PosApiService api;
  final VoidCallback onHold;
  final VoidCallback onNewSale;
  final Future<void> Function(String id, {bool parkCurrentFirst}) onRetrieve;
  final Future<void> Function(Map<String, int> moveQuantities) onSplit;
  final VoidCallback onCancel;
  final ValueChanged<PosPaymentResult> onPayment;
  final bool requestPayment;
  final VoidCallback? onPaymentRequestHandled;

  String _money(int amount) =>
      MoneyFormatter.format(amount, currencyCode: AppConfig.currencyCode);

  IconData _paymentIcon(String value) => switch (value) {
        'cash' => Icons.payments_outlined,
        'card' => Icons.credit_card,
        'mobile_money' => Icons.phone_android,
        'bank_transfer' => Icons.account_balance_outlined,
        'wallet' || 'credit' => Icons.account_balance_wallet_outlined,
        _ => Icons.payments_outlined,
      };

  @override
  Widget build(BuildContext context) {
    if (requestPayment && !cart.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPaymentRequestHandled?.call();
        if (context.mounted) _showPaymentDialog(context);
      });
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= PosUi.deskBreakpoint;
            final actions = wide
                ? Row(
                    children: [
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.person_outline_rounded,
                          label: cart.customer?.displayLabel ?? 'Client',
                          onTap: () => _showCustomerSheet(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.discount_outlined,
                          label: cart.discountTotal > 0
                              ? 'Remise ${_money(cart.discountTotal)}'
                              : 'Remise',
                          onTap: () => _showDiscountDialog(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.note_outlined,
                          label: cart.note ?? 'Note',
                          onTap: () => _showNoteDialog(context),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _ActionChip(
                        icon: Icons.person_outline_rounded,
                        label: cart.customer?.displayLabel ?? 'Client',
                        onTap: () => _showCustomerSheet(context),
                      ),
                      const SizedBox(height: 6),
                      _ActionChip(
                        icon: Icons.discount_outlined,
                        label: cart.discountTotal > 0
                            ? 'Remise ${_money(cart.discountTotal)}'
                            : 'Remise',
                        onTap: () => _showDiscountDialog(context),
                      ),
                      const SizedBox(height: 6),
                      _ActionChip(
                        icon: Icons.note_outlined,
                        label: cart.note ?? 'Note',
                        onTap: () => _showNoteDialog(context),
                      ),
                    ],
                  );
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryRow(label: 'Sous-total', value: _money(cart.subtotal)),
                if (cart.lineDiscountsTotal > 0)
                  _SummaryRow(
                    label: 'Remises ligne',
                    value: '- ${_money(cart.lineDiscountsTotal)}',
                  ),
                if (cart.globalDiscountTotal > 0)
                  _SummaryRow(
                    label: 'Remise globale',
                    value: '- ${_money(cart.globalDiscountTotal)}',
                  ),
                if (cart.feesTotal > 0)
                  _SummaryRow(label: 'Frais', value: _money(cart.feesTotal)),
                _SummaryRow(label: 'Taxes', value: _money(cart.taxTotal)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: AppColors.fieldFill,
                    borderRadius: BorderRadius.circular(PosUi.radiusMd),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL', style: PosUi.totalCaption()),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _money(cart.total),
                          style: PosUi.totalAmount(size: wide ? 30 : 28),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final editing = cart.isEditingHold;
            final buttons = Column(
              children: [
                if (editing) ...[
                  SizedBox(
                    width: double.infinity,
                    height: PosUi.ctaHeight,
                    child: FilledButton.icon(
                      onPressed: cart.isEmpty ? null : onHold,
                      icon: const Icon(Icons.pause_circle_outline, size: 20),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand600,
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.4,
                        ),
                      ),
                      label: const Text('Enregistrer (Attente)'),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cart.isEmpty ? null : onHold,
                          child: const Text('Attente'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onNewSale,
                          child: const Text('Nouvelle'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cart.heldSales.isEmpty
                              ? null
                              : () => _showHeldSalesSheet(context),
                          child: Text('Récup. (${cart.heldSales.length})'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cart.canSplit ? () => _showSplitDialog(context) : null,
                          child: const Text('Séparer'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cart.isEmpty ? null : onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.35)),
                            backgroundColor: AppColors.dangerBg,
                          ),
                          child: const Text('Annuler'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: PosUi.ctaHeight,
                    child: FilledButton(
                      onPressed: cart.isEmpty ? null : () => _showPaymentDialog(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand600,
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.8,
                        ),
                      ),
                      child: const Text('PAYER'),
                    ),
                  ),
                ],
              ],
            );

            if (!wide) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  actions,
                  const SizedBox(height: 10),
                  summary,
                  const SizedBox(height: 8),
                  buttons,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 9, child: actions),
                const SizedBox(width: 16),
                Expanded(flex: 10, child: summary),
                const SizedBox(width: 16),
                Expanded(flex: 12, child: buttons),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCustomerSheet(BuildContext context) async {
    final searchController = TextEditingController();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    List<PosCustomer> results = [];
    var searching = false;
    var creating = false;
    var showCreate = false;
    var loaded = false;
    String? formError;

    Future<void> search(void Function(void Function()) setModalState, [String? query]) async {
      setModalState(() => searching = true);
      try {
        results = await api.searchCustomers(query ?? searchController.text);
      } catch (_) {
        results = [];
      }
      setModalState(() => searching = false);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!loaded) {
              loaded = true;
              WidgetsBinding.instance.addPostFrameCallback((_) => search(setModalState));
            }

            Future<void> create() async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setModalState(() => formError = 'Le nom est requis');
                return;
              }
              setModalState(() {
                creating = true;
                formError = null;
              });
              try {
                final customer = await api.createCustomer(
                  name: name,
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                );
                cart.setCustomer(customer);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (error) {
                setModalState(() {
                  creating = false;
                  formError = error.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Dialog(
              insetPadding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text('Client', style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setModalState(() => showCreate = !showCreate),
                        icon: Icon(showCreate ? Icons.search : Icons.person_add_alt_1, size: 18),
                        label: Text(showCreate ? 'Rechercher' : 'Nouveau client'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (showCreate) ...[
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Téléphone'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Email'),
                      onSubmitted: (_) => create(),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(formError!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: creating ? null : create,
                      child: Text(creating ? 'Enregistrement…' : 'Créer et sélectionner'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Le client est enregistré sur ce terminal, puis envoyé lors de la synchronisation.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ] else ...[
                    TextField(
                      controller: searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Nom, téléphone ou code',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => search(setModalState, searchController.text),
                        ),
                      ),
                      onChanged: (value) => search(setModalState, value),
                      onSubmitted: (value) => search(setModalState, value),
                    ),
                    if (cart.customer != null) ...[
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person),
                        title: Text(cart.customer!.displayLabel),
                        subtitle: Text(cart.customer!.pending ? 'En attente de synchro' : 'Client sélectionné'),
                        trailing: TextButton(
                          onPressed: () {
                            cart.setCustomer(null);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Retirer'),
                        ),
                      ),
                    ],
                    if (searching) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final customer = results[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(customer.name),
                            subtitle: Text(customer.subtitle.isEmpty ? 'Client' : customer.subtitle),
                            onTap: () {
                              cart.setCustomer(customer);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
  }

  Future<void> _showDiscountDialog(BuildContext context) async {
    final amountController = TextEditingController();
    final percentController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Montant fixe (centimes)',
                hintText: 'ex: 500 = 5.00',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: percentController,
              decoration: const InputDecoration(
                labelText: 'Pourcentage (%)',
                hintText: 'ex: 10',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cart.clearDiscount();
              Navigator.pop(ctx, 'cleared');
            },
            child: const Text('Effacer'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'apply'),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );

    if (result == 'apply') {
      final percent = double.tryParse(percentController.text);
      final amount = int.tryParse(amountController.text);
      if (percent != null && percent > 0) {
        cart.setDiscountPercent(percent);
      } else if (amount != null && amount > 0) {
        cart.setDiscountAmount(amount);
      }
    }

    amountController.dispose();
    percentController.dispose();
  }

  Future<void> _showNoteDialog(BuildContext context) async {
    final controller = TextEditingController(text: cart.note);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note de vente'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Note interne...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null) cart.setNote(result);
    controller.dispose();
  }

  Future<void> _printKitchen(PosHeldSale sale) async {
    var ticket = sale;
    if (sale.lines.isEmpty && (sale.serverId?.isNotEmpty ?? false)) {
      final remote = await api.fetchSale(sale.serverId!);
      final items = remote?['items'] as List<dynamic>? ?? [];
      final lines = <PosCartLine>[];
      for (final raw in items.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final productId = item['product_id']?.toString() ?? '';
        if (productId.isEmpty) continue;
        final name = item['product_name']?.toString() ?? item['name']?.toString() ?? 'Article';
        final price = (item['unit_price'] as num?)?.toInt() ?? 0;
        lines.add(
          PosCartLine(
            lineId: item['id']?.toString() ?? productId,
            product: PosProduct(
              storeProductId: productId,
              productId: productId,
              sku: item['product_sku']?.toString() ?? '',
              name: name,
              price: price,
            ),
            unitPrice: price,
            quantity: (item['quantity'] as num?)?.toInt() ?? 1,
          ),
        );
      }
      if (lines.isNotEmpty) {
        ticket = PosHeldSale(
          id: sale.id,
          label: sale.label,
          serverId: sale.serverId,
          lines: lines,
          heldAt: sale.heldAt,
          note: remote?['notes']?.toString(),
        );
      }
    }
    await KitchenTicketService().printHeldSale(ticket);
  }

  Future<void> _showHeldSalesSheet(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Commandes en attente', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Détail, modification, séparation et paiement tant que la commande n’est pas encaissée.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: cart.heldSales.isEmpty
                      ? const Text('Aucune commande en attente.')
                      : ListView(
                          shrinkWrap: true,
                          children: cart.heldSales.map((sale) {
                            final canSplit = sale.lines.length >= 2 ||
                                sale.lines.any((line) => line.quantity > 1);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            sale.label,
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                                          ),
                                        ),
                                        Text(
                                          _formatTime(sale.heldAt),
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    if (sale.customer != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        sale.customer!.displayLabel,
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                    if (sale.note != null && sale.note!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        sale.note!,
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    if (sale.lines.isEmpty)
                                      Text(
                                        'Aucun article (commande distante sans détail local).',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                      )
                                    else
                                      ...sale.lines.map((line) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      line.displayName,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${line.quantity} × ${_money(line.unitPrice)}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        color: AppColors.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                _money(line.lineSubtotal),
                                                style: GoogleFonts.jetBrainsMono(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    const SizedBox(height: 4),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.fieldFill,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            '${sale.itemCount} art.',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Total ',
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            _money(sale.total),
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.brand700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await _retrieveHeld(context, sale.id);
                                          },
                                          child: const Text('Modifier'),
                                        ),
                                        OutlinedButton(
                                          onPressed: !canSplit
                                              ? null
                                              : () async {
                                                  Navigator.pop(ctx);
                                                  await _retrieveHeld(context, sale.id);
                                                  if (!context.mounted) return;
                                                  await _showSplitDialog(context);
                                                },
                                          child: const Text('Séparer'),
                                        ),
                                        FilledButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await _retrieveHeld(context, sale.id);
                                            if (!context.mounted) return;
                                            await _showPaymentDialog(context);
                                          },
                                          child: const Text('Payer'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _printKitchen(sale),
                                          icon: const Icon(Icons.restaurant, size: 16),
                                          label: const Text('Bon de cuisine'),
                                        ),
                                        IconButton(
                                          tooltip: 'Supprimer',
                                          onPressed: () async {
                                            final serverId = sale.serverId;
                                            if (serverId != null && serverId.isNotEmpty) {
                                              try {
                                                await api.discardHold(serverId);
                                              } catch (_) {}
                                            }
                                            cart.deleteHeldSale(sale.id);
                                            if (ctx.mounted) Navigator.pop(ctx);
                                            if (context.mounted) _showHeldSalesSheet(context);
                                          },
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retrieveHeld(BuildContext context, String saleId) async {
    final parkCurrentFirst = !cart.isEmpty;
    await onRetrieve(saleId, parkCurrentFirst: parkCurrentFirst);
  }

  Future<void> _showSplitDialog(BuildContext context) async {
    final moves = await showPosSplitDialog(context, cart);
    if (moves == null || moves.isEmpty) return;
    await onSplit(moves);
  }

  int _parseMajor(String input) {
    final cleaned = input.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    final value = double.tryParse(cleaned) ?? 0;
    return (value * 100).round();
  }

  String _major(int cents) {
    final major = cents / 100;
    return major == major.roundToDouble() ? major.toStringAsFixed(0) : major.toStringAsFixed(2);
  }

  List<PosPaymentMethod> _usableMethods(List<PosPaymentMethod> methods) {
    final source = methods.isEmpty ? PosPaymentMethod.defaults : methods;
    final list = [...source];
    if (!list.any((method) => method.value == 'mobile_money')) {
      final cardIndex = list.indexWhere((method) => method.value == 'card');
      list.insert(
        cardIndex >= 0 ? cardIndex : list.length,
        const PosPaymentMethod(value: 'mobile_money', label: 'Mobile Money', labelFr: 'Mobile Money'),
      );
    }
    return list;
  }

  Future<void> _submitPayments(
    BuildContext context, {
    required List<Map<String, dynamic>> payments,
    required String methodLabel,
    int change = 0,
  }) async {
    try {
      final saleResult = await api.createSale(
        items: cart.lines.map((line) => line.toSaleItem()).toList(),
        payments: payments,
        customerId: cart.customer?.saleCustomerId,
        notes: cart.note,
        saleId: cart.pendingServerId,
      );
      cart.consumeActiveHold();
      cart.cancel();
      onPayment(PosPaymentResult(
        success: true,
        total: saleResult.total,
        method: methodLabel,
        change: change,
        paidAmount: saleResult.paidAmount,
        outstandingAmount: saleResult.outstandingAmount,
        saleId: saleResult.saleId,
        saleReference: saleResult.reference,
        message: saleResult.pendingSync
            ? 'Vente ${saleResult.reference} enregistrée sur cet appareil. Paiement, stock et sync en file — internet non requis.'
            : 'Vente ${saleResult.reference} acceptée',
      ));
    } catch (error) {
      onPayment(PosPaymentResult(
        success: false,
        total: cart.total,
        method: methodLabel,
        message: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _showPaymentDialog(BuildContext context) async {
    PosCustomerBalance? customerBalance;
    final paymentMethods = _usableMethods(await api.fetchPaymentMethods());

    if (cart.customer != null && !cart.customer!.pending) {
      try {
        customerBalance = await api.fetchCustomerBalance(cart.customer!.saleCustomerId);
      } catch (_) {}
    }

    if (!context.mounted) return;
    final result = await showPosPaymentDialog(
      context: context,
      total: cart.total,
      currencyCode: AppConfig.currencyCode,
      methods: paymentMethods,
      customer: cart.customer,
      customerBalance: customerBalance,
      money: _money,
      major: _major,
      parseMajor: _parseMajor,
      paymentIcon: _paymentIcon,
    );

    if (result == null || !context.mounted) return;

    if (result.mode == 'single') {
      final meta = paymentMethods.where((item) => item.value == result.selected).firstOrNull;
      final change = (meta?.supportsChange == true || result.selected == 'cash') ? result.tendered - cart.total : 0;
      await _submitPayments(
        context,
        payments: [
          {
            'method': result.selected,
            'amount': cart.total,
            if (change > 0) 'metadata': {'tendered': result.tendered},
          },
        ],
        methodLabel: result.selected,
        change: change,
      );
      return;
    }

    var change = 0;
    final payments = <Map<String, dynamic>>[];
    for (final line in result.mixed) {
      final meta = paymentMethods.where((item) => item.value == line.method).firstOrNull;
      if (meta?.supportsChange == true && line.tendered > line.amount) {
        change += line.tendered - line.amount;
      }
      payments.add({
        'method': line.method,
        'amount': line.amount,
        if (meta?.supportsChange == true) 'metadata': {'tendered': line.tendered},
      });
    }
    await _submitPayments(context, payments: payments, methodLabel: 'mixed', change: change);
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: AppColors.brand600),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.fieldFill,
          side: BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          minimumSize: const Size(0, PosUi.touchMin),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosUi.radiusMd)),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns selected lineId → qty to move, or null if cancelled.
Future<Map<String, int>?> showPosSplitDialog(BuildContext context, PosCartEngine cart) async {
  if (!cart.canSplit) return null;

  final selected = <String, int>{
    for (final line in cart.lines) line.lineId: 0,
  };

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final moveCount = selected.values.fold<int>(0, (sum, qty) => sum + qty);
          final remainCount = cart.lines.fold<int>(0, (sum, line) {
            final move = selected[line.lineId] ?? 0;
            return sum + (line.quantity - move);
          });
          return AlertDialog(
            title: const Text('Séparer la commande'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choisissez les articles (et quantités) à déplacer vers une nouvelle commande en attente.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: cart.lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final line = cart.lines[index];
                        final move = selected[line.lineId] ?? 0;
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.displayName,
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Qty ${line.quantity}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: move <= 0
                                        ? null
                                        : () => setModalState(() => selected[line.lineId] = move - 1),
                                    icon: const Icon(Icons.remove, size: 18),
                                  ),
                                  Text('$move', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: move >= line.quantity
                                        ? null
                                        : () => setModalState(() => selected[line.lineId] = move + 1),
                                    icon: const Icon(Icons.add, size: 18),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'À séparer: $moveCount · Restent: $remainCount',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(
                onPressed: moveCount > 0 && remainCount > 0 ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Séparer'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true) return null;
  return {
    for (final entry in selected.entries)
      if (entry.value > 0) entry.key: entry.value,
  };
}
