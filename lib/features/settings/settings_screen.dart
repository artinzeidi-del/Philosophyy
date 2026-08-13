import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/l10n/taxonomy_labels.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Settings.
///
/// Everything here is a genuine preference the reader controls, and every
/// control says what it will actually do. There is nothing that nags, nothing
/// buried, and no setting whose off position is quietly worse than its on
/// position.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final language = ref.watch(activeLanguageProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, Spacing.lg, 0, Spacing.xxxl),
          children: <Widget>[
            ReadingColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _GroupLabel(text: l10n.settingsLanguage),
                  RadioGroup<AppLanguage?>(
                    groupValue: settings.language,
                    onChanged: controller.setLanguage,
                    child: Column(
                      children: <Widget>[
                        RadioListTile<AppLanguage?>(
                          value: null,
                          title: Text(l10n.settingsThemeSystem),
                        ),
                        for (final option in AppLanguage.values)
                          RadioListTile<AppLanguage?>(
                            value: option,
                            // Each language is named in itself, so a reader who
                            // has landed in the wrong one can still read the
                            // way out.
                            title: Text(option.endonym),
                          ),
                      ],
                    ),
                  ),

                  _GroupLabel(text: l10n.settingsTheme),
                  RadioGroup<ThemeMode>(
                    groupValue: settings.themeMode,
                    onChanged: (mode) {
                      if (mode != null) controller.setThemeMode(mode);
                    },
                    child: Column(
                      children: <Widget>[
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          title: Text(l10n.settingsThemeSystem),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          title: Text(l10n.settingsThemeLight),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          title: Text(l10n.settingsThemeDark),
                        ),
                      ],
                    ),
                  ),

                  _GroupLabel(text: l10n.settingsReadingLevel),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Text(
                      l10n.settingsReadingLevelHelp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  RadioGroup<LearningLevel>(
                    groupValue: settings.readingLevel,
                    onChanged: (level) {
                      if (level != null) controller.setReadingLevel(level);
                    },
                    child: Column(
                      children: <Widget>[
                        for (final level in LearningLevel.values)
                          RadioListTile<LearningLevel>(
                            value: level,
                            title: Text(
                              TaxonomyLabels.level(level).resolve(language),
                            ),
                            subtitle: Text(
                              TaxonomyLabels.depth(level.defaultDepth)
                                  .resolve(language),
                            ),
                          ),
                      ],
                    ),
                  ),

                  _GroupLabel(text: l10n.navLibrary),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Text(
                      l10n.clearLibraryExplain,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      l10n.clearLibrary,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    onTap: () => _confirmClear(context, ref),
                  ),

                  _GroupLabel(text: l10n.settingsAbout),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l10n.settingsAbout),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: l10n.appName,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before erasing the reader's work.
///
/// This is the one destructive action in the app, and it cannot be undone, so it
/// is the one place a confirmation is warranted — everything else here is
/// reversible by pressing the same control again.
Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
  final l10n = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.clearLibrary),
      content: Text(l10n.clearLibraryExplain),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.clearLibraryConfirm),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  final cleared = await ref.read(libraryProvider.notifier).clearAll();
  messenger.showSnackBar(
    SnackBar(content: Text(cleared ? l10n.clearLibraryDone : l10n.saveFailed)),
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Spacing.lg,
      Spacing.xl,
      Spacing.lg,
      Spacing.sm,
    ),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}
