import 'package:flutter/material.dart';

import '../../../../core/i18n/app_locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../data/pos_api_service.dart';
import '../../domain/pos_models.dart';
import '../../services/pos_cart_engine.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// Customer picker chrome aligned with [LogoutProfileDialog].
Future<void> showCustomerPickerDialog(
  BuildContext context, {
  required PosCartEngine cart,
  required PosApiService api,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.brand900.withValues(alpha: 0.55),
    builder: (context) => CustomerPickerDialog(cart: cart, api: api),
  );
}

class CustomerPickerDialog extends StatefulWidget {
  const CustomerPickerDialog({
    super.key,
    required this.cart,
    required this.api,
  });

  final PosCartEngine cart;
  final PosApiService api;

  @override
  State<CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<CustomerPickerDialog> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  List<PosCustomer> _results = const [];
  var _searching = false;
  var _creating = false;
  var _showCreate = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _searchCustomers();
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _searchCustomers([String? query]) async {
    setState(() => _searching = true);
    try {
      _results = await widget.api.searchCustomers(query ?? _search.text);
    } catch (_) {
      _results = const [];
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Le nom est requis');
      return;
    }
    setState(() {
      _creating = true;
      _formError = null;
    });
    try {
      final customer = await widget.api.createCustomer(
        name: name,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
      );
      widget.cart.setCustomer(customer);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _formError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    final letters = parts.map((part) => part[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.cart.customer;
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400, maxHeight: size.height * 0.86),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.borderXl,
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.elevationMd,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderXl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                  decoration: const BoxDecoration(color: AppColors.brand600),
                  child: Column(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                        ),
                        child: selected == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 42,
                                color: AppColors.brand900,
                              )
                            : Text(
                                tr(_initials(selected.name)),
                                style: AppTypography.text(
                                  color: AppColors.brand900,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('Client'),
                        textAlign: TextAlign.center,
                        style: AppTypography.text(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected == null ? AppColors.textMuted : AppColors.success,
                          borderRadius: AppRadius.borderPill,
                        ),
                        child: Text(
                          tr(selected?.name ?? 'Aucun client'),
                          style: AppTypography.text(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _showCreate
                        ? _CreatePane(
                            key: const ValueKey('create'),
                            name: _name,
                            phone: _phone,
                            email: _email,
                            error: _formError,
                            creating: _creating,
                            onSubmit: _create,
                          )
                        : _SearchPane(
                            key: const ValueKey('search'),
                            search: _search,
                            searching: _searching,
                            results: _results,
                            selected: selected,
                            onSearch: _searchCustomers,
                            onSelect: (customer) {
                              widget.cart.setCustomer(customer);
                              Navigator.pop(context);
                            },
                            onClear: () {
                              widget.cart.setCustomer(null);
                              Navigator.pop(context);
                            },
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: AppButton.secondary(
                          label: _showCreate ? 'Rechercher' : 'Nouveau client',
                          icon: _showCreate
                              ? Icons.search_rounded
                              : Icons.person_add_alt_1_rounded,
                          expanded: true,
                          onPressed: () => setState(() {
                            _showCreate = !_showCreate;
                            _formError = null;
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton.secondary(
                          label: AppCopy.get('cancel'),
                          expanded: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchPane extends StatelessWidget {
  const _SearchPane({
    super.key,
    required this.search,
    required this.searching,
    required this.results,
    required this.selected,
    required this.onSearch,
    required this.onSelect,
    required this.onClear,
  });

  final TextEditingController search;
  final bool searching;
  final List<PosCustomer> results;
  final PosCustomer? selected;
  final ValueChanged<String> onSearch;
  final ValueChanged<PosCustomer> onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            style: AppTypography.text(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: tr('Nom, téléphone ou code'),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: AppColors.fieldFill,
              border: OutlineInputBorder(borderRadius: AppRadius.borderLg),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.borderLg,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.borderLg,
                borderSide: const BorderSide(color: AppColors.brand600, width: 1.5),
              ),
            ),
            onChanged: onSearch,
            onSubmitted: onSearch,
          ),
        ),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: AppRadius.borderLg,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(selected!.displayLabel),
                          style: AppTypography.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          tr(selected!.pending
                              ? 'En attente de synchro'
                              : 'Client sélectionné'),
                          style: AppTypography.text(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onClear,
                    child: Text(
                      tr('Retirer'),
                      style: AppTypography.text(
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (searching)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Flexible(
          child: results.isEmpty && !searching
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr('Aucun client trouvé'),
                    textAlign: TextAlign.center,
                    style: AppTypography.text(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final customer = results[index];
                    final isSelected = selected?.id == customer.id;
                    return Material(
                      color: isSelected
                          ? AppColors.brand600.withValues(alpha: 0.08)
                          : AppColors.fieldFill,
                      borderRadius: AppRadius.borderLg,
                      child: InkWell(
                        borderRadius: AppRadius.borderLg,
                        onTap: () => onSelect(customer),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: AppRadius.borderLg,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brand600
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.person_outline_rounded,
                                size: 22,
                                color: isSelected
                                    ? AppColors.brand700
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr(customer.name),
                                      style: AppTypography.text(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      tr(customer.subtitle.isEmpty
                                          ? 'Client'
                                          : customer.subtitle),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.text(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
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
                ),
        ),
      ],
    );
  }
}

class _CreatePane extends StatelessWidget {
  const _CreatePane({
    super.key,
    required this.name,
    required this.phone,
    required this.email,
    required this.error,
    required this.creating,
    required this.onSubmit,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController email;
  final String? error;
  final bool creating;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    InputDecoration decoration(String label, IconData icon) {
      return InputDecoration(
        isDense: true,
        labelText: tr(label),
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: AppColors.fieldFill,
        border: OutlineInputBorder(borderRadius: AppRadius.borderLg),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderLg,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderLg,
          borderSide: const BorderSide(color: AppColors.brand600, width: 1.5),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            textInputAction: TextInputAction.next,
            style: AppTypography.text(fontSize: 14, color: AppColors.textPrimary),
            decoration: decoration('Nom', Icons.badge_outlined),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            style: AppTypography.text(fontSize: 14, color: AppColors.textPrimary),
            decoration: decoration('Téléphone', Icons.phone_outlined),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            style: AppTypography.text(fontSize: 14, color: AppColors.textPrimary),
            decoration: decoration('Email', Icons.mail_outline),
            onSubmitted: (_) => onSubmit(),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              tr(error!),
              style: AppTypography.text(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 14),
          AppButton.primary(
            label: creating ? 'Enregistrement…' : 'Créer et sélectionner',
            icon: Icons.check_rounded,
            expanded: true,
            loading: creating,
            onPressed: creating ? null : onSubmit,
          ),
          const SizedBox(height: 8),
          Text(
            tr('Le client est enregistré sur ce terminal, puis envoyé lors de la synchronisation.'),
            style: AppTypography.text(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
