/// How precisely a historical year is known.
///
/// Most dates in the history of philosophy are not exact, and pretending they
/// are is an academic-accuracy failure. A philosopher's birth year is very
/// often a scholarly estimate; encoding that estimate as a bare integer loses
/// the qualification the sources actually carry.
enum DatePrecision {
  /// The year is attested and not seriously disputed.
  exact,

  /// Approximately this year ("c. 470 BCE").
  circa,

  /// Known only to the decade.
  decade,

  /// Known only to the century.
  century,
}

/// A year on the proleptic Julian/Gregorian scale where negative values are
/// BCE, together with how precisely it is known.
///
/// There is no year zero in the conventional era, so [year] must not be 0:
/// 1 BCE is `-1` and 1 CE is `1`.
class HistoricalYear implements Comparable<HistoricalYear> {
  HistoricalYear(this.year, {this.precision = DatePrecision.exact})
    : assert(year != 0, 'There is no year zero: 1 BCE is -1 and 1 CE is 1.');

  /// Convenience constructor for a year Before Common Era.
  HistoricalYear.bce(
    int yearBce, {
    DatePrecision precision = DatePrecision.exact,
  }) : this(-yearBce, precision: precision);

  /// Negative for BCE, positive for CE. Never zero.
  final int year;

  /// How precisely [year] is known.
  final DatePrecision precision;

  /// Whether this year falls Before the Common Era.
  bool get isBce => year < 0;

  /// The magnitude of the year, for display alongside a BCE/CE marker.
  int get absoluteYear => year.abs();

  /// Whether the year carries any qualification, which the UI should surface
  /// rather than quietly drop.
  bool get isApproximate => precision != DatePrecision.exact;

  /// The century this year falls in, negative for BCE centuries. The 5th
  /// century BCE is `-5`; the 1st century CE is `1`.
  int get century =>
      isBce ? -((absoluteYear - 1) ~/ 100 + 1) : (year - 1) ~/ 100 + 1;

  @override
  int compareTo(HistoricalYear other) => year.compareTo(other.year);

  @override
  bool operator ==(Object other) =>
      other is HistoricalYear &&
      other.year == year &&
      other.precision == precision;

  @override
  int get hashCode => Object.hash(year, precision);

  @override
  String toString() {
    final prefix = isApproximate ? 'c. ' : '';
    return '$prefix$absoluteYear ${isBce ? 'BCE' : 'CE'}';
  }
}

/// A span between two years, either of which may be unknown.
class HistoricalRange {
  const HistoricalRange({this.start, this.end})
    : assert(
        start != null || end != null,
        'A range with neither endpoint carries no information.',
      );

  /// When the span began, or `null` if unknown.
  final HistoricalYear? start;

  /// When the span ended, or `null` if unknown or still open.
  final HistoricalYear? end;

  /// The length of the span in years, or `null` when an endpoint is missing.
  int? get durationInYears {
    final from = start;
    final to = end;
    if (from == null || to == null) return null;
    // No year zero, so a span crossing the era boundary is one year shorter
    // than raw subtraction suggests.
    final crossesEra = from.isBce && !to.isBce;
    return to.year - from.year - (crossesEra ? 1 : 0);
  }

  /// Whether [year] falls inside this span, treating a missing endpoint as
  /// unbounded on that side.
  bool contains(HistoricalYear year) {
    final from = start;
    final to = end;
    if (from != null && year.year < from.year) return false;
    if (to != null && year.year > to.year) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is HistoricalRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '${start ?? '?'} – ${end ?? '?'}';
}

/// The dates attached to a person.
///
/// For many ancient and medieval figures the birth and death years are lost but
/// a *floruit* — the period they were known to be active — is attested. Keeping
/// [floruit] separate from a guessed lifespan preserves that distinction.
class LifeSpan {
  const LifeSpan({this.birth, this.death, this.floruit});

  /// Year of birth, if known or estimated.
  final HistoricalYear? birth;

  /// Year of death, if known or estimated.
  final HistoricalYear? death;

  /// The period the person was known to be active, used when [birth] and
  /// [death] are unattested.
  final HistoricalRange? floruit;

  /// Whether anything at all is known about when this person lived.
  bool get isKnown => birth != null || death != null || floruit != null;

  /// The best available single year for ordering this person on a timeline.
  ///
  /// Birth is preferred, then the start of the floruit, then death — so a
  /// figure known only by a death date still sorts sensibly rather than being
  /// dropped from chronological views.
  HistoricalYear? get sortAnchor => birth ?? floruit?.start ?? death;

  /// Age at death, when both endpoints are known.
  int? get ageAtDeath => (birth != null && death != null)
      ? HistoricalRange(start: birth, end: death).durationInYears
      : null;

  @override
  bool operator ==(Object other) =>
      other is LifeSpan &&
      other.birth == birth &&
      other.death == death &&
      other.floruit == floruit;

  @override
  int get hashCode => Object.hash(birth, death, floruit);

  @override
  String toString() => 'LifeSpan($birth – $death, fl. $floruit)';
}
