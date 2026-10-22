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
}

abstract final class AndroidLayout {
  /// Smartphone / compact.
  static const phoneMax = 600.0;

  /// Tablette portrait / medium — shell still uses bottom nav below [tabletMax].
  static const tabletMax = 900.0;

  /// Ultra-wide Windows POS desk.
  static const windowsDeskMin = 1280.0;

  /// Two-column settings / wide chrome.
  static const contentWide = 980.0;

  /// Auth hero + form split.
  static const authSplit = 960.0;

  /// Orders detail as dialog vs full page.
  static const ordersDetailDialog = 700.0;

  /// Below this, Orders uses cards instead of a wide table.
  static const ordersTableMin = 760.0;

  /// Target product card width for grid column math.
  static const productCardTarget = 156.0;

  static AndroidFormFactor of(BuildContext context) {
    return fromWidth(MediaQuery.sizeOf(context).width);
  }

  static AndroidFormFactor fromWidth(double width) {
    if (width < phoneMax) return AndroidFormFactor.phone;
    if (width < tabletMax) return AndroidFormFactor.tablet;
    return AndroidFormFactor.desk;
  }

  /// POS three-pane (grid + cart column): desk always; tablet only in landscape.
  static bool usePosThreePane(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final form = fromWidth(size.width);
    if (form.isPhone) return false;
    if (form.isDesk) return true;
    return size.width >= size.height;
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

  /// Product columns from **available** width (parent constraints), not screen width.
  static int productColumns(double availableWidth) {
    if (availableWidth <= 0) return 2;
    if (availableWidth < 360) return 2;
    final raw = (availableWidth / productCardTarget).floor();
    return raw.clamp(2, 6);
  }

  /// Cart rail width for three-pane POS.
  static double posCartWidth({
    required double parentWidth,
    required bool windowsDesk,
    required bool tablet,
  }) {
    final ideal = windowsDesk
        ? 420.0
        : tablet
            ? parentWidth * 0.34
            : parentWidth * 0.30;
    final minW = windowsDesk ? 360.0 : (tablet ? 260.0 : 300.0);
    final maxW = windowsDesk ? 440.0 : (tablet ? 320.0 : 360.0);
    return ideal.clamp(minW, maxW);
  }

  /// Phone drawer cart width.
  static double phoneCartWidth(double screenWidth) {
    if (screenWidth < 400) return screenWidth * 0.92;
    if (screenWidth < phoneMax) return (screenWidth * 0.86).clamp(280.0, 340.0);
    return 320.0;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletMax) {
      return const EdgeInsets.fromLTRB(24, 18, 24, 24);
    }
    if (width >= phoneMax) {
      return const EdgeInsets.fromLTRB(18, 14, 18, 20);
    }
    return const EdgeInsets.fromLTRB(14, 12, 14, 18);
  }

  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletMax ? contentWide : width;
  }

  /// Keep large system fonts readable without blowing fixed POS chrome.
  static TextScaler clampTextScaler(TextScaler scaler) {
    return scaler.clamp(minScaleFactor: 0.90, maxScaleFactor: 1.25);
  }

  static double touchMin(BuildContext context) =>
      preferLite(context) ? 48.0 : 44.0;
}
