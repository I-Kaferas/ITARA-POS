import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../sync/local_master_discovery.dart';
import '../../../../sync/pairing_models.dart';
import '../bloc/master_pairing_bloc.dart';
import 'package:pos_mobile/core/i18n/tr.dart';
import 'package:pos_mobile/core/theme/app_typography.dart';

/// Asks for the Master's 6-digit code, then waits for ACCEPT.
/// Returns true once this device is registered as a slave of [master].
Future<bool> pairWithDiscoveredMaster(
  BuildContext context,
  DiscoveredMaster master,
) async {
  final codeCtrl = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(trf('Secure Pairing — {0}', [master.name])),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('La découverte ne suffit pas. Saisissez le code à 6 chiffres '
            'du Master, puis attendez ACCEPT.'),
            style: AppTypography.text(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('Code d\'appairage'),
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
          child: Text(tr('Demander l\'accés')),
        ),
      ],
    ),
  );
  codeCtrl.dispose();
  if (code == null || code.length != 6 || !context.mounted) return false;

  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final pairing = context.read<MasterPairingBloc>();

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(
            child: Text(tr('Authorization… en attente ACCEPT sur le Master.')),
          ),
        ],
      ),
    ),
  );

  final done = pairing.stream.firstWhere(
    (s) =>
        !s.busy &&
        (s.phase == PairingPhase.registered ||
            s.phase == PairingPhase.rejected),
  );
  pairing.add(MasterPairingSlaveRequested(master: master, code: code));
  await done;
  navigator.pop();

  final err = pairing.state.errorMessage;
  if (err != null) {
    messenger.showSnackBar(SnackBar(content: Text(tr(err))));
    return false;
  }
  messenger.showSnackBar(
    SnackBar(content: Text(tr('Appareil enregistré — appairage réussi.'))),
  );
  return true;
}
