import 'package:philosophyy/core/format/number_format.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Renders historical dates without throwing away what is uncertain about them.
///
/// A formatter that turns `HistoricalYear(-470, circa)` into "470 BCE" has
/// quietly upgraded a scholarly estimate into a fact. Everything here keeps the
/// qualification visible, because in the history of philosophy the
/// qualification is usually the honest part.
abstract final class AppDates {
  /// Formats a single year with its era and any approximation marker.
  static String year(HistoricalYear year, AppLanguage language, AppL10n l10n) {
    final digits = AppNumbers.format(year.absoluteYear, language);
    final withEra = year.isBce
        ? l10n.yearBce(year.absoluteYear)
        : l10n.yearCe(year.absoluteYear);

    // The generated plural-aware getters format the number themselves in
    // Latin digits, so the Persian digits are substituted back in.
    final localized = withEra.replaceFirst(
      year.absoluteYear.toString(),
      digits,
    );

    return year.isApproximate ? l10n.yearApproximate(localized) : localized;
  }

  /// Formats a lifespan as a single line, e.g. "c. 470 – 399 BCE".
  ///
  /// Returns `null` when nothing is known, so callers can omit the line rather
  /// than render an empty label — a date field showing "–" tells the reader
  /// less than no date field at all.
  static String? lifeSpan(LifeSpan life, AppLanguage language, AppL10n l10n) {
    final birth = life.birth;
    final death = life.death;

    if (birth != null && death != null) {
      // When both fall in the same era the era is stated once, at the end.
      if (birth.isBce == death.isBce) {
        final start = birth.isApproximate
            ? l10n.yearApproximate(
                AppNumbers.format(birth.absoluteYear, language),
              )
            : AppNumbers.format(birth.absoluteYear, language);
        return '$start – ${year(death, language, l10n)}';
      }
      return '${year(birth, language, l10n)} – ${year(death, language, l10n)}';
    }

    if (birth != null) return '${l10n.born} ${year(birth, language, l10n)}';
    if (death != null) return '${l10n.died} ${year(death, language, l10n)}';

    // A floruit is marked as one. The domain keeps it apart from a lifespan
    // precisely because it says something weaker — the years someone is known
    // to have been active, for a figure whose birth and death are not
    // attested — and printing it bare would present the weaker claim in the
    // shape of the stronger one.
    final floruit = life.floruit;
    if (floruit != null) {
      final span = range(floruit, language, l10n);
      if (span != null) return l10n.flourished(span);
    }

    return null;
  }

  /// Formats a composition range for a work.
  static String? range(
    HistoricalRange? range,
    AppLanguage language,
    AppL10n l10n,
  ) {
    if (range == null) return null;
    final start = range.start;
    final end = range.end;
    if (start != null && end != null) {
      return '${year(start, language, l10n)} – ${year(end, language, l10n)}';
    }
    if (start != null) return year(start, language, l10n);
    if (end != null) return year(end, language, l10n);
    return null;
  }
}
