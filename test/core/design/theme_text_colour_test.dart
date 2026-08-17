import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/design/app_theme.dart';
import 'package:philosophyy/core/design/contrast.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';

/// Every text style the theme hands to a component must name its colour.
///
/// Material 3's text styles are built with `inherit: false`. A style passed
/// into a theme slot with a null colour therefore does *not* pick one up from
/// the colour scheme — it falls back to black. That is invisible in light mode
/// and unreadable in dark mode, and it is exactly what happened: every label
/// in Settings was black on the dark surface, and had been since the dark
/// theme was written.
void main() {
  for (final (name, theme) in <(String, ThemeData)>[
    ('light', AppTheme.light(AppLanguage.en)),
    ('dark', AppTheme.dark(AppLanguage.en)),
  ]) {
    group('The $name theme', () {
      test('names a colour on every component text style', () {
        final styles = <String, TextStyle?>{
          'listTile title': theme.listTileTheme.titleTextStyle,
          'listTile subtitle': theme.listTileTheme.subtitleTextStyle,
          'appBar title': theme.appBarTheme.titleTextStyle,
          'chip label': theme.chipTheme.labelStyle,
          'chip secondary label': theme.chipTheme.secondaryLabelStyle,
          'dialog title': theme.dialogTheme.titleTextStyle,
          'dialog content': theme.dialogTheme.contentTextStyle,
          'snackBar content': theme.snackBarTheme.contentTextStyle,
          'tooltip': theme.tooltipTheme.textStyle,
          'input hint': theme.inputDecorationTheme.hintStyle,
        };

        for (final entry in styles.entries) {
          final style = entry.value;
          if (style == null) continue;
          expect(
            style.color,
            isNotNull,
            reason:
                '$name: the ${entry.key} style has no colour, so it will be '
                'painted black whatever the surface underneath it is',
          );
        }
      });

      test('those colours are legible on the surface they land on', () {
        final scheme = theme.colorScheme;
        final pairs = <String, (Color?, Color)>{
          'listTile title': (
            theme.listTileTheme.titleTextStyle?.color,
            scheme.surface,
          ),
          'listTile subtitle': (
            theme.listTileTheme.subtitleTextStyle?.color,
            scheme.surface,
          ),
          'appBar title': (
            theme.appBarTheme.titleTextStyle?.color,
            scheme.surface,
          ),
          'input hint': (
            theme.inputDecorationTheme.hintStyle?.color,
            scheme.surfaceContainer,
          ),
          'snackBar content': (
            theme.snackBarTheme.contentTextStyle?.color,
            scheme.inverseSurface,
          ),
          'tooltip': (
            theme.tooltipTheme.textStyle?.color,
            scheme.inverseSurface,
          ),
        };

        for (final entry in pairs.entries) {
          final (foreground, background) = entry.value;
          if (foreground == null) continue;
          final ratio = Contrast.ratio(
            Contrast.composite(foreground, background),
            background,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(Contrast.aaNormalText),
            reason:
                '$name: ${entry.key} is ${ratio.toStringAsFixed(2)}:1 against '
                'the surface it is drawn on',
          );
        }
      });
    });
  }
}
