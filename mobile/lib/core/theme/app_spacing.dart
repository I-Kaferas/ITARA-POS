/// Consistent spacing scale (4–48). Prefer these over magic numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;

  /// Minimum comfortable touch target (Material / POS tactile).
  static const double touchMin = 44;

  /// Primary CTA height on POS surfaces.
  static const double ctaHeight = 48;
}

/// Legacy alias — prefer [AppSpacing].
typedef AppSpace = AppSpacing;
