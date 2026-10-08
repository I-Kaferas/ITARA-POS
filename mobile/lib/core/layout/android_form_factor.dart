import 'package:flutter/material.dart';

/// Form factors Android POS (mobile.md §18).
enum AndroidFormFactor {
  /// Smartphone / petit écran.
  phone,

  /// Tablette / écran tactile moyen.
  tablet,

  /// Large (Windows / tablette paysage large).
  desk,
}

extension AndroidFormFactorX on AndroidFormFactor {
  bool get isPhone => this == AndroidFormFactor.phone;
  bool get isTablet => this == AndroidFormFactor.tablet;
  bool get isDesk => this == AndroidFormFactor.desk;

  /// POS tablette : Sidebar + Product Grid + Cart.
  bool get usePosThreePane => !isPhone;
}

abstract final class AndroidLayout {
  static const phoneMax = 600.0;
  static const tabletMax = 900.0;

  static AndroidFormFactor of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < phoneMax) return AndroidFormFactor.phone;
    if (width < tabletMax) return AndroidFormFactor.tablet;
    return AndroidFormFactor.desk;
  }

  static AndroidFormFactor fromWidth(double width) {
    if (width < phoneMax) return AndroidFormFactor.phone;
    if (width < tabletMax) return AndroidFormFactor.tablet;
    return AndroidFormFactor.desk;
  }

  /// Appareils peu puissants : densité élevée + petit écran → alléger.
  static bool preferLite(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.shortestSide < 360 || mq.devicePixelRatio >= 3.5;
  }

  static Duration anim(BuildContext context, Duration normal) {
    if (preferLite(context)) return Duration.zero;
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;
  }

  static int productColumns(double width) {
    if (width >= 900) return 4;
    if (width >= 720) return 3;
    if (width >= 400) return 2;
    return 2;
  }

  static double touchMin(BuildContext context) =>
      preferLite(context) ? 48.0 : 44.0;
}
