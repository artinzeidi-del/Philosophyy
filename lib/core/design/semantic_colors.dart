import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/color_tokens.dart';

/// Colours that carry product meaning rather than Material roles.
///
/// A [ColorScheme] describes structure — surface, primary, error. It has no
/// vocabulary for "this quotation's attribution is disputed", which is a
/// distinction this product must draw visibly and consistently. Those live
/// here, as a theme extension, so they travel with the theme and can be
/// switched wholesale between light and dark instead of being reached for
/// ad hoc inside widgets.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.quoteSurface,
    required this.onQuoteSurface,
    required this.quoteAccent,
    required this.verified,
    required this.probable,
    required this.disputed,
    required this.misattributed,
    required this.unknownProvenance,
    required this.interpretation,
    required this.scholarlyDisagreement,
    required this.readingSurface,
    required this.highlight,
  });

  /// The light-theme values.
  static const AppSemanticColors light = AppSemanticColors(
    quoteSurface: AppColors.goldContainer,
    onQuoteSurface: AppColors.onGoldContainer,
    quoteAccent: AppColors.gold,
    verified: Color(0xFF2F6B43),
    probable: Color(0xFF6B5A16),
    disputed: Color(0xFF9A5A12),
    misattributed: AppColors.errorLight,
    unknownProvenance: AppColors.inkMuted,
    interpretation: Color(0xFF4B4088),
    scholarlyDisagreement: Color(0xFF7A4A6E),
    readingSurface: Color(0xFFFDFBF7),
    highlight: Color(0xFFFAEBB8),
  );

  /// The dark-theme values.
  static const AppSemanticColors dark = AppSemanticColors(
    quoteSurface: AppColors.goldContainerDark,
    onQuoteSurface: AppColors.onGoldContainerDark,
    quoteAccent: AppColors.goldLight,
    verified: Color(0xFF8FCCA3),
    probable: Color(0xFFD8C177),
    disputed: Color(0xFFEBAE72),
    misattributed: AppColors.errorDark,
    unknownProvenance: AppColors.lamplightMuted,
    interpretation: Color(0xFFB3A8EE),
    scholarlyDisagreement: Color(0xFFDCA7CE),
    readingSurface: Color(0xFF0E1116),
    highlight: Color(0xFF54470F),
  );

  /// Background of a pulled-out quotation.
  final Color quoteSurface;

  /// Text drawn on [quoteSurface].
  final Color onQuoteSurface;

  /// The rule or mark that identifies a quotation.
  final Color quoteAccent;

  /// An attribution confirmed against a primary source.
  final Color verified;

  /// An attribution that is likely but not confirmed.
  final Color probable;

  /// An attribution scholars actively dispute.
  final Color disputed;

  /// An attribution known to be wrong, kept because the misattribution itself
  /// is widespread and worth correcting.
  final Color misattributed;

  /// An attribution nobody has been able to trace.
  final Color unknownProvenance;

  /// Marks a claim as one scholar's reading rather than settled fact.
  final Color interpretation;

  /// Marks a point on which the scholarship genuinely divides.
  final Color scholarlyDisagreement;

  /// The page colour of the long-form reading view, which sits a shade apart
  /// from the app's ordinary surface so that reading feels like a place.
  final Color readingSurface;

  /// A reader's own highlight.
  final Color highlight;

  @override
  AppSemanticColors copyWith({
    Color? quoteSurface,
    Color? onQuoteSurface,
    Color? quoteAccent,
    Color? verified,
    Color? probable,
    Color? disputed,
    Color? misattributed,
    Color? unknownProvenance,
    Color? interpretation,
    Color? scholarlyDisagreement,
    Color? readingSurface,
    Color? highlight,
  }) => AppSemanticColors(
    quoteSurface: quoteSurface ?? this.quoteSurface,
    onQuoteSurface: onQuoteSurface ?? this.onQuoteSurface,
    quoteAccent: quoteAccent ?? this.quoteAccent,
    verified: verified ?? this.verified,
    probable: probable ?? this.probable,
    disputed: disputed ?? this.disputed,
    misattributed: misattributed ?? this.misattributed,
    unknownProvenance: unknownProvenance ?? this.unknownProvenance,
    interpretation: interpretation ?? this.interpretation,
    scholarlyDisagreement: scholarlyDisagreement ?? this.scholarlyDisagreement,
    readingSurface: readingSurface ?? this.readingSurface,
    highlight: highlight ?? this.highlight,
  );

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      quoteSurface: Color.lerp(quoteSurface, other.quoteSurface, t)!,
      onQuoteSurface: Color.lerp(onQuoteSurface, other.onQuoteSurface, t)!,
      quoteAccent: Color.lerp(quoteAccent, other.quoteAccent, t)!,
      verified: Color.lerp(verified, other.verified, t)!,
      probable: Color.lerp(probable, other.probable, t)!,
      disputed: Color.lerp(disputed, other.disputed, t)!,
      misattributed: Color.lerp(misattributed, other.misattributed, t)!,
      unknownProvenance: Color.lerp(
        unknownProvenance,
        other.unknownProvenance,
        t,
      )!,
      interpretation: Color.lerp(interpretation, other.interpretation, t)!,
      scholarlyDisagreement: Color.lerp(
        scholarlyDisagreement,
        other.scholarlyDisagreement,
        t,
      )!,
      readingSurface: Color.lerp(readingSurface, other.readingSurface, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
    );
  }
}

/// Convenient access to [AppSemanticColors] from a [BuildContext].
extension SemanticColorsContext on BuildContext {
  /// The semantic colours for the active theme.
  ///
  /// Falls back to the light values if the extension is somehow absent, so a
  /// misconfigured theme degrades to readable rather than crashing.
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
