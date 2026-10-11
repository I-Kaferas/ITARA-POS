import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/config/terminal_config.dart';
import '../../../core/config/terminal_config_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../sync/offline_store.dart';

/// Profile card shown before logout, with a permissions list on the second step.
Future<bool> showLogoutProfileDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.brand900.withValues(alpha: 0.55),
    builder: (context) => const LogoutProfileDialog(),
  );
  return confirmed == true;
}

class LogoutProfileDialog extends StatefulWidget {
  const LogoutProfileDialog({super.key});

  @override
  State<LogoutProfileDialog> createState() => _LogoutProfileDialogState();
}

class _LogoutProfileDialogState extends State<LogoutProfileDialog> {
  bool _permissions = false;
  String _email = '';
  String _code = '';
  String _role = '';
  Map<String, String> _permissionNames = const {};
  Map<String, String> _permissionGroups = const {};

  TerminalConfig get _config => TerminalConfigRepository.instance.config;

  @override
  void initState() {
    super.initState();
    final config = _config;
    _email = config.cashierEmail.trim();
    _code = config.cashierCode.trim();
    _role = _roleLabel(config.roles, '');
    _load();
  }

  Future<void> _load() async {
    final config = _config;
    try {
      final card = await OfflineStore.instance.lookupCashierCard(
        userId: config.cashierId,
        roleSlugs: config.roles,
      );
      if (!mounted) return;
      setState(() {
        if (_email.isEmpty) _email = card.email;
        if (_code.isEmpty) _code = card.code;
        _role = _roleLabel(config.roles, card.roleName);
        _permissionNames = card.permissionNames;
        _permissionGroups = card.permissionGroups;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final name = config.cashierName.trim().isEmpty ? 'Caissier' : config.cashierName.trim();
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _permissions
                  ? _PermissionsPane(
                      key: const ValueKey('permissions'),
                      slugs: config.permissions,
                      names: _permissionNames,
                      groups: _permissionGroups,
                      onBack: () => setState(() => _permissions = false),
                    )
                  : _ProfilePane(
                      key: const ValueKey('profile'),
                      name: name,
                      initials: _initials(name),
                      code: _code,
                      role: _role,
                      email: _email,
                      id: config.cashierId,
                      onPermissions: () => setState(() => _permissions = true),
                      onCancel: () => Navigator.pop(context, false),
                      onLogout: () => Navigator.pop(context, true),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePane extends StatelessWidget {
  const _ProfilePane({
    super.key,
    required this.name,
    required this.initials,
    required this.code,
    required this.role,
    required this.email,
    required this.id,
    required this.onPermissions,
    required this.onCancel,
    required this.onLogout,
  });

  final String name;
  final String initials;
  final String code;
  final String role;
  final String email;
  final String id;
  final VoidCallback onPermissions;
  final VoidCallback onCancel;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
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
                child: Text(
                  initials,
                  style: GoogleFonts.ibmPlexSans(
                    color: AppColors.brand900,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: GoogleFonts.ibmPlexSans(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (code.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.borderPill,
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: Text(
                    code,
                    style: GoogleFonts.ibmPlexSans(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: AppRadius.borderPill,
                ),
                child: Text(
                  role,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: AppRadius.borderLg,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.mail_outline, label: AppCopy.get('email'), value: email.isEmpty ? '—' : email),
                    const SizedBox(height: 10),
                    _InfoRow(icon: Icons.fingerprint, label: 'ID', value: id.isEmpty ? '—' : id),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: AppButton.secondary(
                  label: AppCopy.get('viewPermissions'),
                  icon: Icons.shield_outlined,
                  expanded: true,
                  onPressed: onPermissions,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: AppCopy.get('cancel'),
                      expanded: true,
                      onPressed: onCancel,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton.danger(
                      label: AppCopy.get('logout'),
                      icon: Icons.logout_rounded,
                      expanded: true,
                      onPressed: onLogout,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 11, color: AppColors.textMuted)),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionsPane extends StatelessWidget {
  const _PermissionsPane({
    super.key,
    required this.slugs,
    required this.names,
    required this.groups,
    required this.onBack,
  });

  final List<String> slugs;
  final Map<String, String> names;
  final Map<String, String> groups;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final sections = _sections(slugs, names, groups);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: AppColors.brand600,
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                AppCopy.get('permissions'),
                style: GoogleFonts.ibmPlexSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Flexible(
          child: sections.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppCopy.get('noRights'),
                    style: GoogleFonts.ibmPlexSans(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  itemCount: sections.length,
                  separatorBuilder: (_, _) => Divider(height: 22, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: GoogleFonts.ibmPlexSans(
                            color: AppColors.brandInk,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final action in section.actions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 18, color: AppColors.success),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    action,
                                    style: GoogleFonts.ibmPlexSans(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
            child: SizedBox(
              width: double.infinity,
              child: AppButton.secondary(
                label: AppCopy.get('backProfile'),
                icon: Icons.arrow_back_rounded,
                expanded: true,
                onPressed: onBack,
              ),
            ),
        ),
      ],
    );
  }
}

class _PermSection {
  const _PermSection(this.title, this.actions);

  final String title;
  final List<String> actions;
}

List<_PermSection> _sections(
  List<String> slugs,
  Map<String, String> names,
  Map<String, String> groups,
) {
  if (slugs.any((slug) => slug == '*' || slug == 'admin')) {
    return const [_PermSection('ACCÈS', ['Tous les droits'])];
  }
  final order = <String>[];
  final buckets = <String, List<String>>{};
  for (final slug in slugs) {
    final trimmed = slug.trim();
    if (trimmed.isEmpty) continue;
    final parts = trimmed.split('.').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) continue;
    final header = _header(parts, groups[trimmed]);
    final action = _action(parts, names[trimmed]);
    final list = buckets.putIfAbsent(header, () {
      order.add(header);
      return <String>[];
    });
    if (!list.contains(action)) list.add(action);
  }
  return [for (final title in order) _PermSection(title, buckets[title]!)];
}

String _header(List<String> parts, String? group) {
  if (parts.length >= 3) {
    return '${parts.first.toUpperCase()}  ›  ${_label(parts[1]).toUpperCase()}';
  }
  final area = (group == null || group.trim().isEmpty ? parts.first : group).replaceAll('_', ' ');
  return area.toUpperCase();
}

String _action(List<String> parts, String? name) {
  final stored = name?.trim() ?? '';
  if (stored.isNotEmpty && !stored.contains(' ')) return stored;
  return _label(parts.last);
}

String _label(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
  final letters = parts.map((part) => part[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}

String _roleLabel(List<String> slugs, String storedName) {
  if (storedName.trim().isNotEmpty) return storedName.trim();
  const known = {
    'cashier': 'Caissier',
    'server': 'Serveur',
    'serveur': 'Serveur',
    'waiter': 'Serveur',
    'store_manager': 'Responsable magasin',
    'branch_manager': 'Responsable',
    'administrator': 'Admin',
    'admin': 'Admin',
    'company_owner': 'Propriétaire',
    'super_admin': 'Super admin',
    'inventory_manager': 'Responsable stock',
  };
  for (final slug in slugs) {
    final key = slug.trim().toLowerCase();
    if (key.isEmpty) continue;
    return known[key] ?? _label(key);
  }
  return 'Caissier';
}
