import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/color_tokens.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';

/// Assembles the Material theme from the design tokens.
///
/// Light and dark are built by the same function from two different schemes,
/// but they are not each other's inverse: the dark theme drops shadows in
/// favour of surface separation, because a shadow cast on a near-black
/// background is invisible and only serves to muddy the edge it was meant to
/// define.
///
/// ## The shapes
///
/// Controls are pills and panels are softly rounded, which is the difference
/// between an interface that looks assembled from a component library and one
/// that looks designed. The primary action carries a bloom in its own colour —
/// the one place in the system where a glow means "this is what to press" —
/// and every other control is quiet enough for that to register. See
/// `core/design/glass.dart` for the rule the glow follows.
abstract final class AppTheme {
  /// The light theme, typeset for [language].
  static ThemeData light(AppLanguage language) =>
      _build(AppColors.light, AppSemanticColors.light, language);

  /// The dark theme, typeset for [language].
  static ThemeData dark(AppLanguage language) =>
      _build(AppColors.dark, AppSemanticColors.dark, language);

  static ThemeData _build(
    ColorScheme scheme,
    AppSemanticColors semantic,
    AppLanguage language,
  ) {
    final textTheme = AppTypography.forLanguage(language);
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[semantic],

      // A visible, high-contrast focus ring is the only way keyboard and
      // switch users can tell where they are.
      focusColor: scheme.primary.withValues(alpha: 0.12),
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        // Transparent, so the canvas runs behind the bar rather than being
        // covered by a rectangle of the surface colour at the top of every
        // screen. Screens that need an opaque bar set one themselves.
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: Elevations.none,
        scrolledUnderElevation: isDark ? Elevations.none : Elevations.card,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),

      cardTheme: CardThemeData(
        color: scheme.surfaceContainer.withValues(alpha: isDark ? 0.62 : 0.78),
        surfaceTintColor: Colors.transparent,
        // Dark mode separates surfaces by lightness, not by shadow.
        elevation: isDark ? Elevations.none : Elevations.card,
        shadowColor: scheme.shadow.withValues(alpha: 0.10),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.surfaceRadius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: Spacing.lg,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh.withValues(
          alpha: isDark ? 0.55 : 0.85,
        ),
        // Same rule as the segments: what is chosen is the bright one.
        selectedColor: scheme.primary,
        checkmarkColor: scheme.onPrimary,
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimary,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.surfaceRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.surfaceRadius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.surfaceRadius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.surfaceRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              textStyle: textTheme.labelLarge,
              // 48dp of height keeps every primary action above the minimum
              // comfortable touch target on every platform.
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              shape: const StadiumBorder(),
              // The bloom is what marks this as the action to take, so it is
              // spent here and almost nowhere else. `elevation` with a coloured
              // `shadowColor` is how Material paints one without a second widget
              // wrapping every button in the product.
              elevation: 8,
              shadowColor: scheme.primary.withValues(
                alpha: isDark ? 0.55 : 0.34,
              ),
            ).copyWith(
              // Pressed and disabled must not glow: a disabled control that still
              // blooms is telling the reader to press something that will not
              // respond.
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return 0;
                if (states.contains(WidgetState.pressed)) return 2;
                return 8;
              }),
            ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          side: BorderSide(color: scheme.outline),
          shape: const StadiumBorder(),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const CircleBorder(),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: textTheme.labelLarge,
          // The selected segment is the bright accent with dark ink on it, and
          // the unselected ones are quiet. Material's defaults invert that —
          // it draws unselected segments in the primary colour — so the
          // segment a reader was *not* on read as the louder of the two.
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.onSurfaceVariant,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          side: BorderSide(color: scheme.outlineVariant),
          shape: const StadiumBorder(),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outlineVariant,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        // The colour is not optional here. Material 3's text styles are built
        // with `inherit: false`, so a style handed to a theme slot with a null
        // colour does not pick one up from the scheme — it falls back to
        // black. Every settings label was black on the dark surface, which is
        // unreadable, and it had been that way for as long as the dark theme
        // has existed.
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xs,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.sm)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        elevation: Elevations.none,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium?.copyWith(color: scheme.onSurface)
              : textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.lg)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.lg)),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.md)),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
