import 'package:flutter/material.dart';

import '../config/terminal_config_repository.dart';
import '../theme/app_colors.dart';

/// Locales shared with the web app: French, English, Kiswahili.
abstract final class AppLocales {
  static const codes = ['fr', 'en', 'sw'];

  static const labels = {
    'fr': 'Français',
    'en': 'English',
    'sw': 'Kiswahili',
  };

  static String normalize(String? value) {
    final code = (value ?? '').trim().toLowerCase();
    return codes.contains(code) ? code : 'fr';
  }
}

class LocaleController extends ChangeNotifier {
  LocaleController._();

  static final instance = LocaleController._();

  String code = 'fr';

  Locale get locale => Locale(code);

  void bind(String? value) {
    final next = AppLocales.normalize(value);
    if (next == code) return;
    code = next;
    notifyListeners();
  }

  Future<void> apply(String value) async {
    bind(value);
    final repo = TerminalConfigRepository.instance;
    if (!repo.isLoaded) return;
    if (repo.config.locale == code) return;
    await repo.save(repo.config.copyWith(locale: code));
  }
}

/// Copy for launch, configuration, sync and logout. Other screens stay as written.
abstract final class AppCopy {
  static String get(String key) {
    final pack = _packs[LocaleController.instance.code] ?? _fr;
    return pack[key] ?? _fr[key] ?? key;
  }

  static const _fr = {
    'language': 'Langue',
    'settingsMode': 'Configuration',
    'ownerHint': 'Connectez-vous avec le compte administrateur du commerce.',
    'ownerBadge': 'Accès administrateur',
    'emailHint': 'E-mail administrateur',
    'passwordHint': 'Mot de passe',
    'signIn': 'Se connecter',
    'greetMorning': 'Bonjour',
    'greetAfternoon': 'Bon après-midi',
    'greetEvening': 'Bonsoir',
    'pinTitle': 'Ouverture de caisse',
    'pinHint': 'Saisissez votre code à 4 chiffres.',
    'registerReady': 'Votre caisse est prête.',
    'loginHeadline': 'Encaisser devient simple.',
    'loginPitch': 'Vendez, suivez le stock et passez d’un magasin à l’autre, depuis la même caisse.',
    'loginSale': 'Encaissement',
    'loginSaleHint': 'PIN, tickets et paiements',
    'loginStock': 'Stock',
    'loginStockHint': 'Inventaire tenu à jour',
    'loginShops': 'Magasins',
    'loginShopsHint': 'Un terminal, plusieurs boutiques',
    'useKeypad': 'Afficher le clavier',
    'hideKeypad': 'Masquer le clavier',
    'serverRunning': 'Serveur en ligne',
    'serverOffline': 'Serveur hors ligne',
    'staffMode': 'Caisse',
    'rootMode': 'Admin',
    'serverConnection': 'Connexion au serveur',
    'apiUrl': 'Adresse de l’API',
    'tenantSlugLabel': 'Commerce',
    'adminOnly': 'Ce compte n’a pas l’accès administrateur de ce commerce.',
    'tenantMismatch': 'Ce compte n’appartient pas à ce commerce. Connectez-vous avec son administrateur.',
    'storeMismatch': 'Ce magasin n’appartient pas à ce commerce.',
    'tenantNotFound': 'Ce commerce est introuvable.',
    'tenantInactive': 'Ce commerce n’est pas actif.',
    'storeNotFound': 'Ce magasin est introuvable.',
    'sessionExpired': 'Session expirée. Reconnectez-vous.',
    'connectionFailed': 'Impossible de joindre le serveur. Vérifiez que l’API tourne sur 127.0.0.1:8001, puis réessayez.',
    'validationFailed': 'Email, mot de passe ou PIN incorrect.',
    'welcomeTitle': 'Bienvenue sur ITARA POS',
    'welcomeBody': 'La langue est choisie ici. Ensuite, le compte administrateur ouvre la configuration complète du commerce.',
    'createMaster': 'Créer un Master',
    'connectMaster': 'Rejoindre un Master',
    'welcomeFoot': 'Hors ligne · Master / Esclave · Réseau local',
    'configTitle': 'Configuration',
    'tenantAccess': 'Commerce',
    'secTerminal': 'Terminal',
    'secTerminalHint': 'Identité et mode',
    'secStore': 'Magasin',
    'secStoreHint': 'Commerce connecté',
    'secLink': 'Connexion',
    'secLinkHint': 'Serveurs et jeton',
    'secPrint': 'Impression',
    'secPrintHint': 'Ticket',
    'secParams': 'Paramètres',
    'secParamsHint': 'Tout le commerce',
    'save': 'Enregistrer',
    'logout': 'Déconnexion',
    'reconfigure': 'Reconfigurer',
    'resetTitle': 'Reconfigurer le terminal ?',
    'resetBody': 'Les identifiants locaux seront effacés. Au prochain lancement, choisissez la langue puis le compte administrateur du commerce.',
    'cancel': 'Annuler',
    'continue': 'Continuer',
    'saved': 'Réglages enregistrés',
    'syncTitle': 'Synchronisation',
    'syncSend': 'Envoyer le stock',
    'syncDownload': 'Télécharger le stock',
    'syncBusy': 'Synchronisation en cours…',
    'syncDone': 'Synchronisation terminée',
    'syncFailed': 'Échec',
    'viewPermissions': 'Voir les permissions',
    'permissions': 'Permissions',
    'backProfile': 'Retour au profil',
    'noRights': 'Aucun droit enregistré pour ce profil.',
    'email': 'E-mail',
  };

  static const _en = {
    'language': 'Language',
    'settingsMode': 'Configuration',
    'ownerHint': 'Sign in with the store administrator account.',
    'ownerBadge': 'Administrator access',
    'emailHint': 'Administrator email',
    'passwordHint': 'Password',
    'signIn': 'Sign in',
    'greetMorning': 'Good morning',
    'greetAfternoon': 'Good afternoon',
    'greetEvening': 'Good evening',
    'pinTitle': 'Open the register',
    'pinHint': 'Enter your 4-digit code.',
    'registerReady': 'Your register is ready.',
    'loginHeadline': 'Checkout, made simple.',
    'loginPitch': 'Sell, track stock, and move between shops from the same register.',
    'loginSale': 'Checkout',
    'loginSaleHint': 'PIN, receipts and payments',
    'loginStock': 'Stock',
    'loginStockHint': 'Inventory kept current',
    'loginShops': 'Shops',
    'loginShopsHint': 'One terminal, several stores',
    'useKeypad': 'Show keypad',
    'hideKeypad': 'Hide keypad',
    'serverRunning': 'Server online',
    'serverOffline': 'Server offline',
    'staffMode': 'Register',
    'rootMode': 'Admin',
    'serverConnection': 'Server connection',
    'apiUrl': 'API address',
    'tenantSlugLabel': 'Business',
    'adminOnly': 'This account does not have administrator access for this store.',
    'tenantMismatch': 'This account does not belong to this business. Sign in with its administrator.',
    'storeMismatch': 'This store does not belong to this business.',
    'tenantNotFound': 'This business was not found.',
    'tenantInactive': 'This business is not active.',
    'storeNotFound': 'This store was not found.',
    'sessionExpired': 'Session expired. Sign in again.',
    'connectionFailed': 'Cannot reach the server. Check that the API is running on 127.0.0.1:8001, then try again.',
    'validationFailed': 'Email, password or PIN is incorrect.',
    'welcomeTitle': 'Welcome to ITARA POS',
    'welcomeBody': 'Choose the language here. The administrator account then opens the full store configuration.',
    'createMaster': 'Create a Master',
    'connectMaster': 'Join a Master',
    'welcomeFoot': 'Offline-first · Master / Slave · Local network',
    'configTitle': 'Configuration',
    'tenantAccess': 'Store',
    'secTerminal': 'Terminal',
    'secTerminalHint': 'Identity and mode',
    'secStore': 'Store',
    'secStoreHint': 'Connected business',
    'secLink': 'Connection',
    'secLinkHint': 'Servers and token',
    'secPrint': 'Printing',
    'secPrintHint': 'Receipt',
    'secParams': 'Settings',
    'secParamsHint': 'Whole store',
    'save': 'Save',
    'logout': 'Log out',
    'reconfigure': 'Reconfigure',
    'resetTitle': 'Reconfigure this terminal?',
    'resetBody': 'Local credentials will be cleared. On the next launch, choose the language and the store administrator account.',
    'cancel': 'Cancel',
    'continue': 'Continue',
    'saved': 'Settings saved',
    'syncTitle': 'Sync',
    'syncSend': 'Send stock',
    'syncDownload': 'Download stock',
    'syncBusy': 'Sync in progress…',
    'syncDone': 'Sync finished',
    'syncFailed': 'Failed',
    'viewPermissions': 'View permissions',
    'permissions': 'Permissions',
    'backProfile': 'Back to profile',
    'noRights': 'No rights stored for this profile.',
    'email': 'Email',
  };

  static const _sw = {
    'language': 'Lugha',
    'settingsMode': 'Mipangilio',
    'ownerHint': 'Ingia kwa akaunti ya msimamizi wa duka.',
    'ownerBadge': 'Ufikiaji wa msimamizi',
    'emailHint': 'Barua pepe ya msimamizi',
    'passwordHint': 'Nenosiri',
    'signIn': 'Ingia',
    'greetMorning': 'Habari ya asubuhi',
    'greetAfternoon': 'Habari ya mchana',
    'greetEvening': 'Habari ya jioni',
    'pinTitle': 'Fungua kasha',
    'pinHint': 'Weka namba yako ya tarakimu 4.',
    'registerReady': 'Kasha lako liko tayari.',
    'loginHeadline': 'Malipo yanakuwa rahisi.',
    'loginPitch': 'Uza, fuatilia stoo, na badilisha maduka kutoka kasha moja.',
    'loginSale': 'Malipo',
    'loginSaleHint': 'PIN, risiti na malipo',
    'loginStock': 'Stoo',
    'loginStockHint': 'Hesabu iliyosasishwa',
    'loginShops': 'Maduka',
    'loginShopsHint': 'Kifaa kimoja, maduka mengi',
    'useKeypad': 'Onyesha kibodi',
    'hideKeypad': 'Ficha kibodi',
    'serverRunning': 'Seva iko mtandaoni',
    'serverOffline': 'Seva iko nje ya mtandao',
    'staffMode': 'Kasha',
    'rootMode': 'Admin',
    'serverConnection': 'Muunganisho wa seva',
    'apiUrl': 'Anwani ya API',
    'tenantSlugLabel': 'Biashara',
    'adminOnly': 'Akaunti hii haina ufikiaji wa msimamizi wa duka hili.',
    'tenantMismatch': 'Akaunti hii si ya biashara hii. Ingia na msimamizi wake.',
    'storeMismatch': 'Duka hili si la biashara hii.',
    'tenantNotFound': 'Biashara hii haipatikani.',
    'tenantInactive': 'Biashara hii haijaamilishwa.',
    'storeNotFound': 'Duka hili halipatikani.',
    'sessionExpired': 'Kipindi kimekwisha. Ingia tena.',
    'connectionFailed': 'Seva haipatikani. Hakikisha API inaendesha kwenye 127.0.0.1:8001, kisha jaribu tena.',
    'validationFailed': 'Barua pepe, nenosiri au PIN si sahihi.',
    'welcomeTitle': 'Karibu ITARA POS',
    'welcomeBody': 'Chagua lugha hapa. Akaunti ya msimamizi inafungua mipangilio yote ya duka.',
    'createMaster': 'Unda Master',
    'connectMaster': 'Jiunge na Master',
    'welcomeFoot': 'Nje ya mtandao · Master / Slave · Mtandao wa ndani',
    'configTitle': 'Mipangilio',
    'tenantAccess': 'Duka',
    'secTerminal': 'Kifaa',
    'secTerminalHint': 'Utambulisho na hali',
    'secStore': 'Duka',
    'secStoreHint': 'Biashara iliyounganishwa',
    'secLink': 'Muunganisho',
    'secLinkHint': 'Seva na tokeni',
    'secPrint': 'Uchapishaji',
    'secPrintHint': 'Risiti',
    'secParams': 'Mipangilio',
    'secParamsHint': 'Duka zima',
    'save': 'Hifadhi',
    'logout': 'Toka',
    'reconfigure': 'Sanidi upya',
    'resetTitle': 'Sanidi upya kifaa hiki?',
    'resetBody': 'Vitambulisho vya ndani vitafutwa. Uanzishaji ujao, chagua lugha kisha akaunti ya msimamizi.',
    'cancel': 'Ghairi',
    'continue': 'Endelea',
    'saved': 'Mipangilio imehifadhiwa',
    'syncTitle': 'Usawazishaji',
    'syncSend': 'Tuma stoku',
    'syncDownload': 'Pakua stoku',
    'syncBusy': 'Usawazishaji unaendelea…',
    'syncDone': 'Usawazishaji umekamilika',
    'syncFailed': 'Imeshindwa',
    'viewPermissions': 'Tazama ruhusa',
    'permissions': 'Ruhusa',
    'backProfile': 'Rudi kwenye wasifu',
    'noRights': 'Hakuna ruhusa zilizohifadhiwa.',
    'email': 'Barua pepe',
  };

  static const _packs = {'fr': _fr, 'en': _en, 'sw': _sw};
}

/// Turns an API error code such as `errors.tenant_forbidden` into the active language.
String humanizeApiCode(String raw) {
  final code = raw.trim();
  const known = <String, String>{
    'errors.tenant_forbidden': 'tenantMismatch',
    'errors.store_forbidden': 'storeMismatch',
    'errors.tenant_not_found': 'tenantNotFound',
    'errors.tenant_inactive': 'tenantInactive',
    'errors.store_not_found': 'storeNotFound',
    'errors.store_inactive': 'storeMismatch',
    'errors.unauthenticated': 'sessionExpired',
    'errors.validation': 'validationFailed',
    'errors.connection': 'connectionFailed',
    'errors.offline': 'connectionFailed',
    'errors.network': 'connectionFailed',
  };
  for (final entry in known.entries) {
    if (code == entry.key || code.contains(entry.key)) {
      return AppCopy.get(entry.value);
    }
  }

  final lower = code.toLowerCase();
  if (lower.contains('x-tenant-id header is required')) {
    return AppCopy.get('tenantNotFound');
  }
  if (lower.contains('clientexception') ||
      lower.contains('socketexception') ||
      lower.contains('timeoutexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection timed out') ||
      lower.contains('network is unreachable') ||
      lower.contains('failed to fetch')) {
    return AppCopy.get('connectionFailed');
  }
  return code;
}

/// Prefers the first field message from an API error body over the generic code.
String apiEnvelopeMessage(Object? body, {String fallback = 'Connexion refusée'}) {
  if (body is Map) {
    final errors = body['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        final text = _firstApiErrorText(value);
        if (text != null) return humanizeApiCode(text);
      }
    }
    final message = body['message']?.toString().trim() ?? '';
    if (message.isNotEmpty) return humanizeApiCode(message);
  }
  return humanizeApiCode(fallback);
}

String? _firstApiErrorText(Object? value) {
  if (value is List) {
    for (final item in value) {
      final text = item?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
  }
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        final current = LocaleController.instance.code;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppCopy.get('language'),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in AppLocales.codes)
                  Builder(
                    builder: (context) {
                      final selected = current == code;
                      return ChoiceChip(
                        showCheckmark: false,
                        label: Text(
                          AppLocales.labels[code]!,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: selected,
                        color: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.brand600;
                          }
                          return AppColors.fieldFill;
                        }),
                        side: BorderSide(color: selected ? AppColors.brand600 : AppColors.border),
                        onSelected: (_) => LocaleController.instance.apply(code),
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
