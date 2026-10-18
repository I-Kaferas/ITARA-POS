import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_radius.dart';
import 'app_typography.dart';
import 'theme_controller.dart';

abstract final class AppTheme {
  static ThemeData get light => forPalette(AppPalette.light, Brightness.light);

  static ThemeData get dark => forPalette(AppPalette.dark, Brightness.dark);

  static ThemeData forPalette(AppPalette palette, Brightness brightness) {
    final previous = ThemeController.instance.isDark ? AppPalette.dark : AppPalette.light;
    AppColors.bind(palette);
    final theme = _build(brightness);
    AppColors.bind(previous);
    return theme;
  }

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand700,
        brightness: brightness,
        primary: dark ? AppColors.brandInk : AppColors.brand700,
        onPrimary: dark ? AppColors.brand900 : Colors.white,
        secondary: AppColors.accent,
        onSecondary: AppColors.brand900,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      dividerColor: AppColors.border,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.iOS: AppPageTransitionsBuilder(),
          TargetPlatform.macOS: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
          TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: AppTypography.sectionTitle(),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand700,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.brand700.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          backgroundColor: AppColors.surface,
          side: BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandInk,
          textStyle: AppTypography.button(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brand500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: AppTypography.caption(),
        labelStyle: AppTypography.label(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: const Color(0x7514202B),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderXxl,
          side: BorderSide(color: AppColors.border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        titleTextStyle: AppTypography.title(),
        contentTextStyle: AppTypography.body(color: AppColors.textSecondary),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.body(weight: FontWeight.w600),
        subtitleTextStyle: AppTypography.caption(),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowHeight: 44,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 64,
        horizontalMargin: 16,
        columnSpacing: 16,
        headingTextStyle: AppTypography.overline(),
        dataTextStyle: AppTypography.form(),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
        textStyle: AppTypography.body(),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: AppColors.border,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: AppTypography.form(weight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.form(weight: FontWeight.w500),
        labelColor: AppColors.brandInk,
        unselectedLabelColor: AppColors.textMuted,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: const Color(0x7514202B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        backgroundColor: AppColors.sidebar,
        contentTextStyle: AppTypography.body(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.brandInk,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTypography.label().copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTypography.label(),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.sidebar,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: AppColors.sidebarText),
        selectedLabelTextStyle: AppTypography.label(color: Colors.white).copyWith(fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: AppTypography.label(color: AppColors.sidebarText),
        indicatorColor: AppColors.sidebarActive,
        labelType: NavigationRailLabelType.all,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brand100,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.label(
            color: selected ? AppColors.brandInk : AppColors.textMuted,
          ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.fieldFill,
        selectedColor: AppColors.brand600,
        disabledColor: AppColors.brand50,
        labelStyle: AppTypography.label(color: AppColors.textPrimary),
        secondaryLabelStyle: AppTypography.label(color: Colors.white),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return TextTheme(
      displayLarge: AppTypography.display(),
      displayMedium: AppTypography.pageTitle(),
      displaySmall: AppTypography.titleLarge(),
      headlineLarge: AppTypography.titleLarge(),
      headlineMedium: AppTypography.sectionTitle(),
      headlineSmall: AppTypography.titleSmall(),
      titleLarge: AppTypography.sectionTitle(),
      titleMedium: AppTypography.titleSmall(),
      titleSmall: AppTypography.jakarta(
        fontSize: AppTextSize.base,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: AppTypography.body(),
      bodyMedium: AppTypography.body(),
      bodySmall: AppTypography.form(),
      labelLarge: AppTypography.button(),
      labelMedium: AppTypography.label(),
      labelSmall: AppTypography.caption(),
    );
  }
}
