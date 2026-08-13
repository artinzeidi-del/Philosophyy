import 'package:flutter/material.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

/// The reader's preferences.
///
/// [language] is nullable on purpose: `null` means "whatever the device is set
/// to", which is a genuinely different state from having chosen English. A
/// reader who has never opened settings should follow their phone when they
/// change its language; a reader who chose Persian on an English phone should
/// not have that choice quietly overridden.
@immutable
class AppSettings {
  const AppSettings({
    this.language,
    this.themeMode = ThemeMode.system,
    this.readingLevel = LearningLevel.beginner,
  });

  /// The reader's explicit language choice, or `null` to follow the device.
  final AppLanguage? language;

  /// Light, dark, or follow the device.
  final ThemeMode themeMode;

  /// How much detail entries should open with.
  final LearningLevel readingLevel;

  /// The language to actually render in, given what the platform reports.
  AppLanguage resolveLanguage(Locale platformLocale) =>
      language ?? AppLanguage.fromCode(platformLocale.languageCode);

  /// The depth an entry opens at, derived from the reader's level.
  ContentDepth get defaultDepth => readingLevel.defaultDepth;

  /// Returns a copy with the given fields replaced.
  ///
  /// [language] cannot be cleared through this method because `null` means
  /// "unchanged" here; [clearLanguage] exists for returning to the device
  /// default.
  AppSettings copyWith({
    AppLanguage? language,
    ThemeMode? themeMode,
    LearningLevel? readingLevel,
  }) => AppSettings(
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
    readingLevel: readingLevel ?? this.readingLevel,
  );

  /// Returns a copy that follows the device language again.
  AppSettings clearLanguage() =>
      AppSettings(themeMode: themeMode, readingLevel: readingLevel);

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.language == language &&
      other.themeMode == themeMode &&
      other.readingLevel == readingLevel;

  @override
  int get hashCode => Object.hash(language, themeMode, readingLevel);

  @override
  String toString() =>
      'AppSettings(language: $language, theme: $themeMode, '
      'level: ${readingLevel.id})';
}
