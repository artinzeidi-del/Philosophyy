import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';

/// Where an entry sits in the whole span this reference covers.
///
/// ## Why this exists, and why it is not a portrait
///
/// Every entry in the product was words and nothing else. The request was for
/// pictures, and the honest answer is that no picture of Thales exists: the
/// busts that circulate under his name are Roman imaginings carved four
/// centuries after he died, and the product's rule — stated where the monogram
/// is defined — is that a plausible-looking likeness of somebody nobody has a
/// likeness of is the same defect as a plausible-looking citation.
///
/// What the corpus does hold, for every one of its entries, is *when*. All 191
/// philosophers carry a datable life, all 186 works a date of composition, all
/// 29 schools a period, and every concept the philosophers who argued it. So
/// this draws the thing that is actually known, and it turns out to be worth
/// looking at: the marks are the rest of the corpus, and their crowding shows
/// where the written record thickens and where it nearly disappears.
///
/// It is an image with something to say, which is the only kind worth adding.
class TimelineBand extends StatelessWidget {
  const TimelineBand({
    required this.span,
    required this.others,
    required this.caption,
    this.startLabel,
    this.endLabel,
    super.key,
  });

  /// The entry's own span. A single year is drawn as a point.
  final HistoricalRange span;

  /// One anchor year for every other entry of the same kind, which become the
  /// faint marks behind the lit one.
  final List<int> others;

  /// What the reader is looking at, in their language.
  final String caption;

  /// The years at each end of the band, already formatted and localised.
  final String? startLabel;
  final String? endLabel;

  /// The band's own bounds, widened past the data so nothing sits on an edge.
  static (int, int) boundsOf(Iterable<int> years) {
    if (years.isEmpty) return (-2500, 2100);
    var low = years.first;
    var high = years.first;
    for (final year in years) {
      if (year < low) low = year;
      if (year > high) high = year;
    }
    // A tenth of the range as breathing room, so the earliest entry is not
    // painted half off the left edge.
    final pad = ((high - low) * 0.04).round().clamp(20, 400);
    return (low - pad, high + pad);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final anchors = <int>[
      ...others,
      if (span.start != null) span.start!.year,
      if (span.end != null) span.end!.year,
    ];
    final (low, high) = boundsOf(anchors);

    return Semantics(
      // The painting is decorative to a screen reader; the caption is the
      // content, and it already says the same thing in words.
      label: caption,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 46),
                painter: _BandPainter(
                  low: low,
                  high: high,
                  from: span.start?.year,
                  to: span.end?.year,
                  others: others,
                  track: scheme.surfaceContainerHighest,
                  mark: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                  lit: scheme.primary,
                  edge: Glass.border(context),
                ),
              ),
            ),
            if (startLabel != null || endLabel != null) ...<Widget>[
              const SizedBox(height: Spacing.xs),
              // Forced left-to-right, like the band above it. The painter
              // never mirrors — time does not — so a row that did mirror would
              // print the earliest year under the band's latest end.
              //
              // `Expanded` on both rather than a `Row` with `spaceBetween`:
              // the labels are dates in the reader's language, and in Persian
              // at twice the text size the pair overflowed a 320-point phone
              // by 44 pixels. Neither can be made narrower than its own words,
              // so each takes half the row and wraps inside it.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        startLabel ?? '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        endLabel ?? '',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.sm),
            Text(
              caption,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the band: a track, the rest of the corpus as ticks, and this entry
/// lit on top of them.
class _BandPainter extends CustomPainter {
  const _BandPainter({
    required this.low,
    required this.high,
    required this.from,
    required this.to,
    required this.others,
    required this.track,
    required this.mark,
    required this.lit,
    required this.edge,
  });

  final int low;
  final int high;
  final int? from;
  final int? to;
  final List<int> others;
  final Color track;
  final Color mark;
  final Color lit;
  final Color edge;

  /// The band is always drawn left to right, in both languages.
  ///
  /// Time is the one axis that does not mirror. A Persian reader reads the page
  /// right to left and still expects the earlier century to the left of the
  /// later one, because that is how every timeline, every dynasty chart and
  /// every history textbook in Persian is drawn. Mirroring it would put 2000 CE
  /// before 500 BCE.
  double _x(int year, double width) =>
      ((year - low) / (high - low)).clamp(0.0, 1.0) * width;

  @override
  void paint(Canvas canvas, Size size) {
    const bandTop = 14.0;
    const bandHeight = 18.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, bandTop, size.width, bandHeight),
      const Radius.circular(bandHeight / 2),
    );

    canvas.drawRRect(rect, Paint()..color = track);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // The rest of the corpus. Clipped to the band so the ticks cannot spill
    // out of its rounded ends.
    canvas.save();
    canvas.clipRRect(rect);
    final tick = Paint()
      ..color = mark
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final year in others) {
      final x = _x(year, size.width);
      canvas.drawLine(
        Offset(x, bandTop + 4),
        Offset(x, bandTop + bandHeight - 4),
        tick,
      );
    }
    canvas.restore();

    // This entry. A span becomes a capsule; a single year becomes a dot, and
    // either way it gets a minimum width so a seventy-year life on a
    // four-thousand-year band is still something you can see.
    final startYear = from ?? to;
    if (startYear == null) return;
    final endYear = to ?? from!;
    final left = _x(startYear, size.width);
    final right = _x(endYear, size.width);
    final width = (right - left).clamp(6.0, size.width);
    final x = (left + (right - left) / 2 - width / 2).clamp(
      0.0,
      size.width - width,
    );

    final litRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, bandTop - 3, width, bandHeight + 6),
      const Radius.circular((bandHeight + 6) / 2),
    );
    // The bloom first, so the capsule sits on top of its own light.
    canvas.drawRRect(
      litRect.inflateRect(3),
      Paint()
        ..color = lit.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(litRect, Paint()..color = lit);
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.low != low ||
      old.high != high ||
      old.from != from ||
      old.to != to ||
      old.lit != lit ||
      old.track != track ||
      old.mark != mark ||
      !identical(old.others, others);
}

/// A rounded rectangle inflated on every side.
extension on RRect {
  RRect inflateRect(double by) => RRect.fromRectAndRadius(
    outerRect.inflate(by),
    Radius.circular(blRadiusY + by),
  );
}
