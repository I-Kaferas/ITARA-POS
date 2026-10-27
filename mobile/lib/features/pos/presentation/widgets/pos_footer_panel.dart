import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../hospitality/data/hospitality_api.dart';
import '../../../receipt/services/kitchen_ticket_service.dart';
import '../../../receipt/services/print_once.dart';
import '../../data/pos_api_service.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_cart_engine.dart';
import '../bloc/product_bloc.dart';
import 'customer_picker_dialog.dart';
import 'pos_discount_dialog.dart';
import 'pos_payment_dialog.dart';
import 'pos_ui.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

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
    this.requestCustomer = false,
    this.onCustomerRequestHandled,
    this.requestRetrieve = false,
    this.onRetrieveRequestHandled,
    this.requestDiscount = false,
    this.onDiscountRequestHandled,
    this.requestNote = false,
    this.onNoteRequestHandled,
    this.requestLoyalty = false,
    this.onLoyaltyRequestHandled,
    this.requestSplit = false,
    this.onSplitRequestHandled,
    this.showShortcutLabels = false,
    this.hideChrome = false,
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
  final bool requestCustomer;
  final VoidCallback? onCustomerRequestHandled;
  final bool requestRetrieve;
  final VoidCallback? onRetrieveRequestHandled;
  final bool requestDiscount;
  final VoidCallback? onDiscountRequestHandled;
  final bool requestNote;
  final VoidCallback? onNoteRequestHandled;
  final bool requestLoyalty;
  final VoidCallback? onLoyaltyRequestHandled;
  final bool requestSplit;
  final VoidCallback? onSplitRequestHandled;
  final bool showShortcutLabels;
  final bool hideChrome;

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
    if (requestCustomer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onCustomerRequestHandled?.call();
        if (context.mounted) _showCustomerSheet(context);
      });
    }
    if (requestRetrieve) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onRetrieveRequestHandled?.call();
        if (context.mounted && cart.heldSales.isNotEmpty) {
          _showHeldSalesSheet(context);
        }
      });
    }
    if (requestDiscount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onDiscountRequestHandled?.call();
        if (context.mounted) _showDiscountDialog(context);
      });
    }
    if (requestNote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onNoteRequestHandled?.call();
        if (context.mounted) _showNoteDialog(context);
      });
    }
    if (requestLoyalty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onLoyaltyRequestHandled?.call();
        if (context.mounted) _showLoyaltyDialog(context);
      });
    }
    if (requestSplit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSplitRequestHandled?.call();
        if (context.mounted && cart.canSplit) _showSplitDialog(context);
      });
    }
    if (hideChrome) return const SizedBox.shrink();
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
                          label: showShortcutLabels
                              ? '${cart.customer?.displayLabel ?? 'Client'} · F3'
                              : (cart.customer?.displayLabel ?? 'Client'),
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
                          icon: Icons.stars_outlined,
                          label: cart.loyaltyPoints > 0
                              ? 'Fidélité ${cart.loyaltyPoints} pts'
                              : 'Fidélité',
                          onTap: () => _showLoyaltyDialog(context),
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
                _SummaryRow(label: tr('Sous-total'), value: _money(cart.subtotal)),
                if (cart.lineDiscountsTotal > 0)
                  _SummaryRow(
                    label: tr('Remises ligne'),
                    value: '- ${_money(cart.lineDiscountsTotal)}',
                  ),
                if (cart.globalDiscountTotal > 0)
                  _SummaryRow(
                    label: tr('Remise globale'),
                    value: '- ${_money(cart.globalDiscountTotal)}',
                  ),
                if (cart.feesTotal > 0)
                  _SummaryRow(label: tr('Frais'), value: _money(cart.feesTotal)),
                _SummaryRow(label: tr('Taxes'), value: _money(cart.taxTotal)),
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
                      Text(tr('TOTAL'), style: PosUi.totalCaption()),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          tr(_money(cart.total)),
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
                        textStyle: AppTypography.text(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: 0.4,
                        ),
                      ),
                      label: Text(tr('Enregistrer (Attente)')),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cart.isEmpty ? null : onHold,
                          child: Text(tr(showShortcutLabels ? 'Attente · F5' : 'Attente')),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onNewSale,
                          child: Text(tr(showShortcutLabels ? 'Nouvelle · F2' : 'Nouvelle')),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: cart.heldSales.isEmpty
                              ? null
                              : () => _showHeldSalesSheet(context),
                          child: Text(
                            tr(showShortcutLabels
                                ? 'Récup. (${cart.heldSales.length}) · F6'
                                : 'Récup. (${cart.heldSales.length})'),
                          ),
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
                          child: Text(tr('Séparer')),
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
                          child: Text(tr(showShortcutLabels ? 'Annuler · ESC' : 'Annuler')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: cart.isEmpty || cart.customer == null ? null : () => _chargeStay(context),
                      child: Text(tr('Facturer au séjour')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: PosUi.ctaHeight,
                    child: FilledButton(
                      onPressed: cart.isEmpty ? null : () => _showPaymentDialog(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand600,
                        textStyle: AppTypography.text(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.8,
                        ),
                      ),
                      child: Text(tr(showShortcutLabels ? 'PAYER · F4' : 'PAYER')),
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

  Future<void> _showCustomerSheet(BuildContext context) {
    return showCustomerPickerDialog(context, cart: cart, api: api);
  }

  Future<void> _showDiscountDialog(BuildContext context) async {
    await showPosDiscountDialog(
      context: context,
      cart: cart,
      money: _money,
      major: _major,
      parseMajor: _parseMajor,
    );
  }

  Future<void> _showLoyaltyDialog(BuildContext context) async {
    final customer = cart.customer;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Sélectionnez un client pour utiliser la fidélité'))),
      );
      return;
    }

    PosLoyaltySummary? summary;
    try {
      summary = await api.fetchLoyalty(customer.saleCustomerId);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(error.toString().replaceFirst('Exception: ', '')))),
      );
      return;
    }
    if (!context.mounted) return;

    final pointsCtrl = TextEditingController(
      text: cart.loyaltyPoints > 0 ? '${cart.loyaltyPoints}' : '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Fidélité')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trf('{0} points · {1}', [summary!.points, summary.tier ?? 'Standard'])),
            if (summary.rewardPerPoint > 0)
              Text(trf('1 pt = {0}', [_money(summary.rewardPerPoint)]), style: PosUi.caption()),
            const SizedBox(height: 12),
            TextField(
              controller: pointsCtrl,
              decoration: InputDecoration(labelText: tr('Points à utiliser')),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cart.clearLoyalty();
              Navigator.pop(ctx, 'cleared');
            },
            child: Text(tr('Effacer')),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'apply'), child: Text(tr('Appliquer'))),
        ],
      ),
    );

    if (result == 'apply') {
      final points = int.tryParse(pointsCtrl.text.trim()) ?? 0;
      if (points > 0) {
        cart.setLoyaltyPoints(points.clamp(0, summary.points));
      }
    }
    pointsCtrl.dispose();
  }

  Future<void> _showNoteDialog(BuildContext context) async {
    final controller = TextEditingController(text: cart.note);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Note de vente')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(hintText: tr('Note interne...')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(tr('Enregistrer')),
          ),
        ],
      ),
    );

    if (result != null) cart.setNote(result);
    controller.dispose();
  }

  Future<void> _printKitchen(BuildContext context, PosHeldSale sale) async {
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
          tableId: sale.tableId,
          tableLabel: sale.tableLabel,
        );
      }
    }
    try {
      await KitchenTicketService().printHeldSale(ticket);
    } on PrintAlreadyDone {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Déjà imprimé'))),
        );
      }
    } catch (_) {
      // §41 — kitchen print failure must not cancel the sale / hold.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Impression cuisine échouée — la commande reste ouverte')),
          ),
        );
      }
    }
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
                Text(tr('Commandes en attente'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  tr('Détail, modification, séparation et paiement tant que la commande n’est pas encaissée.'),
                  style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: cart.heldSales.isEmpty
                      ? Text(tr('Aucune commande en attente.'))
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
                                            tr(sale.label),
                                            style: AppTypography.text(fontWeight: FontWeight.w700, fontSize: 14),
                                          ),
                                        ),
                                        Text(
                                          tr(_formatTime(sale.heldAt)),
                                          style: AppTypography.text(fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                    if (sale.customer != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        tr(sale.customer!.displayLabel),
                                        style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                    if (sale.note != null && sale.note!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        tr(sale.note!),
                                        style: AppTypography.text(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    if (sale.lines.isEmpty)
                                      Text(
                                        tr('Aucun article (commande distante sans détail local).'),
                                        style: AppTypography.text(fontSize: 12, color: AppColors.textMuted),
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
                                                      tr(line.displayName),
                                                      style: AppTypography.text(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      trf('{0} × {1}', [line.quantity, _money(line.unitPrice)]),
                                                      style: AppTypography.text(
                                                        fontSize: 11,
                                                        color: AppColors.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                tr(_money(line.lineSubtotal)),
                                                style: GoogleFonts.ibmPlexMono(
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
                                            trf('{0} art.', [sale.itemCount]),
                                            style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          const Spacer(),
                                          Text(
                                            tr('Total '),
                                            style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            tr(_money(sale.total)),
                                            style: GoogleFonts.ibmPlexMono(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.brandInk,
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
                                          child: Text(tr('Modifier')),
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
                                          child: Text(tr('Séparer')),
                                        ),
                                        FilledButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await _retrieveHeld(context, sale.id);
                                            if (!context.mounted) return;
                                            await _showPaymentDialog(context);
                                          },
                                          child: Text(tr('Payer')),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _printKitchen(ctx, sale),
                                          icon: const Icon(Icons.restaurant, size: 16),
                                          label: Text(tr('Bon de cuisine')),
                                        ),
                                        IconButton(
                                          tooltip: tr('Supprimer'),
                                          onPressed: () async {
                                            final restored = await api.voidLocalSale(sale.id);
                                            final serverId = sale.serverId;
                                            if (restored == null && serverId != null && serverId.isNotEmpty) {
                                              try {
                                                await api.discardHold(serverId);
                                              } catch (_) {}
                                            }
                                            if (restored != null && restored.isNotEmpty && context.mounted) {
                                              context.read<ProductBloc>().add(ProductStockAdjusted(restored));
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
        PosPaymentMethod(value: 'mobile_money', label: tr('Mobile Money'), labelFr: 'Mobile Money'),
      );
    }
    if (!list.any((method) => method.value == 'credit')) {
      list.add(PosPaymentMethod(
        value: 'credit',
        label: tr('Credit'),
        labelFr: 'Crédit client',
        requiresCustomer: true,
      ));
    } else {
      final index = list.indexWhere((method) => method.value == 'credit');
      final existing = list[index];
      if (!existing.requiresCustomer) {
        list[index] = PosPaymentMethod(
          value: existing.value,
          label: existing.label,
          labelFr: existing.labelFr,
          requiresCustomer: true,
          supportsChange: existing.supportsChange,
          sortOrder: existing.sortOrder,
        );
      }
    }
    return list.where((method) => method.value != 'room').toList();
  }

  Future<void> _submitPayments(
    BuildContext context, {
    required List<Map<String, dynamic>> payments,
    required String methodLabel,
    int change = 0,
  }) async {
    try {
      if (cart.serviceMode == 'delivery' && cart.deliveryAddress.trim().isEmpty && (cart.tableId == null || cart.tableId!.isEmpty)) {
        onPayment(PosPaymentResult(
          success: false,
          total: cart.total,
          method: methodLabel,
          message: tr('Indiquez une adresse de livraison.'),
        ));
        return;
      }
      final atTable = cart.tableId != null && cart.tableId!.isNotEmpty;
      final saleItems = cart.lines.map((line) => line.toSaleItem()).toList();
      final previewStock = <Map<String, dynamic>>[
        for (final line in cart.lines)
          if (line.stockUpdatePreview != null) line.stockUpdatePreview!,
      ];
      final saleResult = await api.createSale(
        items: saleItems,
        payments: payments,
        customerId: cart.customer?.saleCustomerId,
        notes: cart.note,
        saleId: cart.pendingServerId,
        loyaltyPoints: cart.loyaltyPoints > 0 ? cart.loyaltyPoints : null,
        serviceMode: atTable ? null : cart.serviceMode,
        deliveryAddress: !atTable && cart.serviceMode == 'delivery' ? cart.deliveryAddress.trim() : null,
        tableId: atTable ? cart.tableId : null,
        tableLabel: atTable ? cart.tableDisplay : null,
      );
      cart.consumeActiveHold();
      cart.cancel();
      final stockUpdates = saleResult.stockUpdates.isNotEmpty ? saleResult.stockUpdates : previewStock;
      onPayment(PosPaymentResult(
        success: true,
        total: saleResult.total,
        method: methodLabel,
        change: change,
        paidAmount: saleResult.paidAmount,
        outstandingAmount: saleResult.outstandingAmount,
        saleId: saleResult.saleId,
        saleReference: saleResult.reference,
        receipt: saleResult.receipt,
        loyaltyEarned: saleResult.loyaltyEarned,
        stockUpdates: stockUpdates,
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

  Future<void> _chargeStay(BuildContext context) async {
    try {
      final snapshot = await HospitalityApi().snapshot();
      final docs = (snapshot['docs'] as List?) ?? const [];
      final stays = docs.whereType<Map>().where((doc) {
        return doc['kind'] == 'reservation' && doc['status'] == 'checked_in';
      }).map((doc) => Map<String, dynamic>.from(doc)).toList();
      if (!context.mounted) return;
      if (stays.isEmpty) {
        onPayment(PosPaymentResult(
          success: false,
          total: cart.total,
          method: 'room',
          message: tr('Aucun séjour ouvert.'),
        ));
        return;
      }
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(tr('Facturer au séjour'))),
              for (final stay in stays)
                ListTile(
                  title: Text('${stay['room_number'] ?? ''} · ${stay['guest_name'] ?? ''}'),
                  subtitle: Text('${stay['arrive_on'] ?? ''} – ${stay['depart_on'] ?? ''}'),
                  onTap: () => Navigator.pop(sheetContext, stay),
                ),
            ],
          ),
        ),
      );
      if (picked == null || !context.mounted) return;
      await _submitPayments(
        context,
        payments: [
          {
            'method': 'room',
            'amount': cart.total,
            'metadata': {'reservation_id': picked['id']},
          },
        ],
        methodLabel: 'room',
      );
    } catch (error) {
      onPayment(PosPaymentResult(
        success: false,
        total: cart.total,
        method: 'room',
        message: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _showPaymentDialog(BuildContext context) async {
    try {
      PosCustomerBalance? customerBalance;
      List<PosPaymentMethod> paymentMethods;
      try {
        paymentMethods = _usableMethods(await api.fetchPaymentMethods());
      } catch (_) {
        paymentMethods = _usableMethods(const []);
      }

      if (cart.customer != null && !cart.customer!.pending) {
        try {
          customerBalance = await api.fetchCustomerBalance(cart.customer!.saleCustomerId);
        } catch (_) {}
      }

      if (!context.mounted) return;
      final result = await showPosPaymentDialog(
        context: context,
        total: cart.total,
        subtotal: cart.subtotal,
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
        final change = (meta?.supportsChange == true || result.selected == 'cash')
            ? result.tendered - cart.total
            : 0;
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
    } catch (error) {
      onPayment(PosPaymentResult(
        success: false,
        total: cart.total,
        method: 'unknown',
        message: error.toString().replaceFirst('Exception: ', ''),
      ));
    }
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
        icon: Icon(icon, size: 16, color: AppColors.brandInk),
        label: Text(tr(label), overflow: TextOverflow.ellipsis),
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
            tr(label),
            style: AppTypography.text(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          Text(
            tr(value),
            style: AppTypography.text(
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
            title: Text(tr('Séparer la commande')),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('Choisissez les articles (et quantités) à déplacer vers une nouvelle commande en attente.'),
                    style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
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
                                tr(line.displayName),
                                style: AppTypography.text(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    trf('Qty {0}', [line.quantity]),
                                    style: AppTypography.text(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: move <= 0
                                        ? null
                                        : () => setModalState(() => selected[line.lineId] = move - 1),
                                    icon: const Icon(Icons.remove, size: 18),
                                  ),
                                  Text('$move', style: AppTypography.text(fontWeight: FontWeight.w700)),
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
                    trf('À séparer: {0} · Restent: {1}', [moveCount, remainCount]),
                    style: AppTypography.text(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler'))),
              FilledButton(
                onPressed: moveCount > 0 && remainCount > 0 ? () => Navigator.pop(ctx, true) : null,
                child: Text(tr('Séparer')),
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
