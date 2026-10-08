import 'app_error.dart';

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
        detail: 'La vente reste enregistrée. Vous pourrez réimprimer le ticket.',
        cause: cause,
      );

  factory PrinterError.paperOut({Object? cause}) => PrinterError(
        title: 'Plus de papier dans l’imprimante.',
        detail: 'Rechargez le rouleau puis relancez l’impression.',
        cause: cause,
      );

  factory PrinterError.timeout({Object? cause}) => PrinterError(
        title: 'L’imprimante ne répond pas.',
        detail: 'Vérifiez le câble ou le Wi-Fi de l’imprimante puis réessayez.',
        cause: cause,
      );
}
