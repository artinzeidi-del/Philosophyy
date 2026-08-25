import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/design/color_tokens.dart';
import 'package:philosophyy/core/design/contrast.dart';
import 'package:philosophyy/core/design/gradients.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';

/// Guards the palette against accessibility regressions.
///
/// A colour palette is accessible on the day it is designed and stops being so
/// the first time somebody nudges a value to make a screenshot look better.
/// These tests make that nudge fail the build.
void main() {
  group('Contrast mathematics', () {
    test('black on white is the maximum ratio of 21:1', () {
      expect(
        Contrast.ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.01),
      );
    });

    test('a colour against itself is 1:1', () {
      expect(
        Contrast.ratio(AppColors.emberDeep, AppColors.emberDeep),
        closeTo(1.0, 0.0001),
      );
    });

    test('ratio is symmetric', () {
      expect(
        Contrast.ratio(AppColors.ink, AppColors.blush),
        closeTo(Contrast.ratio(AppColors.blush, AppColors.ink), 0.0001),
      );
    });

    test('relative luminance matches the WCAG reference values', () {
      expect(
        Contrast.relativeLuminance(const Color(0xFFFFFFFF)),
        closeTo(1.0, 0.0001),
      );
      expect(
        Contrast.relativeLuminance(const Color(0xFF000000)),
        closeTo(0.0, 0.0001),
      );
      // sRGB mid-grey #808080 has a published relative luminance of ~0.2159.
      expect(
        Contrast.relativeLuminance(const Color(0xFF808080)),
        closeTo(0.2159, 0.001),
      );
    });

    test('compositing a translucent foreground reduces its contrast', () {
      const background = AppColors.blush;
      final opaque = Contrast.ratio(AppColors.ink, background);
      final translucent = Contrast.ratio(
        Contrast.composite(AppColors.ink.withValues(alpha: 0.5), background),
        background,
      );
      expect(translucent, lessThan(opaque));
    });
  });

  group('Palette meets WCAG AA', () {
    /// The pairs that carry body text. These must clear 4.5:1.
    void expectBodyTextPairs(ColorScheme scheme, String themeName) {
      final pairs = <String, (Color, Color)>{
        'onSurface on surface': (scheme.onSurface, scheme.surface),
        'onSurfaceVariant on surface': (
          scheme.onSurfaceVariant,
          scheme.surface,
        ),
        'onSurface on surfaceContainer': (
          scheme.onSurface,
          scheme.surfaceContainer,
        ),
        'onSurfaceVariant on surfaceContainer': (
          scheme.onSurfaceVariant,
          scheme.surfaceContainer,
        ),
        'onSurface on surfaceContainerHigh': (
          scheme.onSurface,
          scheme.surfaceContainerHigh,
        ),
        'onSurface on surfaceContainerHighest': (
          scheme.onSurface,
          scheme.surfaceContainerHighest,
        ),
        'primary on surface': (scheme.primary, scheme.surface),
        'onPrimary on primary': (scheme.onPrimary, scheme.primary),
        'onPrimaryContainer on primaryContainer': (
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        ),
        'secondary on surface': (scheme.secondary, scheme.surface),
        'onSecondary on secondary': (scheme.onSecondary, scheme.secondary),
        'onSecondaryContainer on secondaryContainer': (
          scheme.onSecondaryContainer,
          scheme.secondaryContainer,
        ),
        'onTertiaryContainer on tertiaryContainer': (
          scheme.onTertiaryContainer,
          scheme.tertiaryContainer,
        ),
        'error on surface': (scheme.error, scheme.surface),
        'onError on error': (scheme.onError, scheme.error),
        'onErrorContainer on errorContainer': (
          scheme.onErrorContainer,
          scheme.errorContainer,
        ),
        'onInverseSurface on inverseSurface': (
          scheme.onInverseSurface,
          scheme.inverseSurface,
        ),
      };

      for (final entry in pairs.entries) {
        final (foreground, background) = entry.value;
        final ratio = Contrast.ratio(
          Contrast.composite(foreground, background),
          background,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(Contrast.aaNormalText),
          reason:
              '$themeName: ${entry.key} is ${ratio.toStringAsFixed(2)}:1, '
              'below the AA minimum of ${Contrast.aaNormalText}:1',
        );
      }
    }

    /// Non-text pairs — borders, dividers and control outlines. These carry
    /// meaning, so AA requires 3:1 of them even though they are not text.
    void expectNonTextPairs(ColorScheme scheme, String themeName) {
      final pairs = <String, (Color, Color)>{
        'outline on surface': (scheme.outline, scheme.surface),
        'outline on surfaceContainer': (
          scheme.outline,
          scheme.surfaceContainer,
        ),
      };

      for (final entry in pairs.entries) {
        final (foreground, background) = entry.value;
        final ratio = Contrast.ratio(
          Contrast.composite(foreground, background),
          background,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(Contrast.aaNonText),
          reason:
              '$themeName: ${entry.key} is ${ratio.toStringAsFixed(2)}:1, '
              'below the AA non-text minimum of ${Contrast.aaNonText}:1',
        );
      }
    }

    test('light scheme body text', () {
      expectBodyTextPairs(AppColors.light, 'light');
    });

    test('light scheme non-text elements', () {
      expectNonTextPairs(AppColors.light, 'light');
    });

    test('dark scheme body text', () {
      expectBodyTextPairs(AppColors.dark, 'dark');
    });

    test('dark scheme non-text elements', () {
      expectNonTextPairs(AppColors.dark, 'dark');
    });

    test(
      'text on the quotation card clears AA at the alpha it is drawn at',
      () {
        // The palette pairs are checked at full strength. The quotation card
        // draws three things on one surface at three strengths — the quotation
        // itself opaque, the original script under it, and the romanisation
        // under that — and a translucent foreground is a different colour from
        // the one in the palette.
        //
        // Caught by measuring rather than by eye: a romanisation added at 0.6
        // came out at 4.19:1 on the light card and 3.73:1 on the dark, both
        // under the bar, and looked perfectly reasonable in a screenshot.
        for (final entry in <String, AppSemanticColors>{
          'light': AppSemanticColors.light,
          'dark': AppSemanticColors.dark,
        }.entries) {
          for (final alpha in <double>[1, 0.72]) {
            final drawn = Color.alphaBlend(
              entry.value.onQuoteSurface.withValues(alpha: alpha),
              entry.value.quoteSurface,
            );
            final ratio = Contrast.ratio(drawn, entry.value.quoteSurface);
            expect(
              ratio,
              greaterThanOrEqualTo(Contrast.aaNormalText),
              reason:
                  '${entry.key}: text at alpha $alpha on the quotation card is '
                  '${ratio.toStringAsFixed(2)}:1, below '
                  '${Contrast.aaNormalText}:1',
            );
          }
        }
      },
    );

    test('primary body text clears AAA on both reading surfaces', () {
      // Long-form reading is the product's core activity, so the two colours a
      // reader looks at for minutes at a time are held to the stricter bar.
      expect(
        Contrast.ratio(AppColors.light.onSurface, AppColors.light.surface),
        greaterThanOrEqualTo(Contrast.aaaNormalText),
      );
      expect(
        Contrast.ratio(AppColors.dark.onSurface, AppColors.dark.surface),
        greaterThanOrEqualTo(Contrast.aaaNormalText),
      );
    });

    /// Every stop as it actually appears, which is under the sheen.
    ///
    /// Measuring the declared stops is measuring a colour that is never on
    /// screen: every gradient surface in the product puts [GradientSheen] over
    /// it, and a wash of the foreground colour lightens the background the
    /// foreground then has to survive. Checked the declared way, the muted
    /// foreground looked safe at 3.86:1 and was 2.89:1 on the hero card.
    List<Color> stopsAsPainted() => <Color>[
      for (final stop in AppGradients.allStops) ...<Color>[
        stop,
        Contrast.composite(
          AppGradients.onGradient.withValues(alpha: GradientSheen.peakStrength),
          stop,
        ),
      ],
    ];

    test('every gradient stop can carry the gradient foreground', () {
      // The ramp is handed out by index, so a caller colours a list of thirty
      // traditions without being asked whether its label will survive.
      for (final stop in stopsAsPainted()) {
        final ratio = Contrast.ratio(AppGradients.onGradient, stop);
        expect(
          ratio,
          greaterThanOrEqualTo(Contrast.aaNormalText),
          reason:
              'the gradient foreground is ${ratio.toStringAsFixed(2)}:1 on '
              '$stop, below the AA minimum',
        );
      }
    });

    test('the muted gradient foreground clears AA for body text', () {
      // It labels captions and metadata, which are set small. The large-text
      // bar would be the wrong one to hold it to.
      for (final stop in stopsAsPainted()) {
        final ratio = Contrast.ratio(AppGradients.onGradientMuted, stop);
        expect(
          ratio,
          greaterThanOrEqualTo(Contrast.aaNormalText),
          reason:
              'the muted gradient foreground is ${ratio.toStringAsFixed(2)}:1 '
              'on $stop',
        );
      }
    });

    test('neither theme uses pure black or pure white as a reading surface', () {
      // Stated as an intentional design constraint so that "fixing" contrast by
      // reaching for #FFFFFF or #000000 fails loudly instead of quietly
      // degrading long-form reading comfort.
      expect(AppColors.light.surface, isNot(const Color(0xFFFFFFFF)));
      expect(AppColors.light.onSurface, isNot(const Color(0xFF000000)));
      expect(AppColors.dark.surface, isNot(const Color(0xFF000000)));
      expect(AppColors.dark.onSurface, isNot(const Color(0xFFFFFFFF)));
    });
  });
}
