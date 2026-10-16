import 'app_error.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

/// Receipt / kitchen printer failure.
final class PrinterError extends AppError {
  const PrinterError({
    super.title = 'Impression impossible.',
    super.detail =
        'Vérifiez que l’imprimante est allumée et connectée, puis réessayez.',
    super.cause,
  }) : super(code: 'errors.printer');

  factory PrinterError.offline({String? printerName, Object? cause}) =>
      PrinterError(
        title: printerName == null
            ? 'Imprimante hors ligne.'
            : 'Imprimante « $printerName » hors ligne.',
        detail: tr('La vente reste enregistrée. Vous pourrez réimprimer le ticket.'),
        cause: cause,
      );

  factory PrinterError.paperOut({Object? cause}) => PrinterError(
        title: tr('Plus de papier dans l’imprimante.'),
        detail: tr('Rechargez le rouleau puis relancez l’impression.'),
        cause: cause,
      );

  factory PrinterError.timeout({Object? cause}) => PrinterError(
        title: tr('L’imprimante ne répond pas.'),
        detail: tr('Vérifiez le câble ou le Wi-Fi de l’imprimante puis réessayez.'),
        cause: cause,
      );
}
