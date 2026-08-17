import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/motion.dart';
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
                  _ChoicePanel<AppLanguage?>(
                    selected: settings.language,
                    onChanged: controller.setLanguage,
                    options: <_Choice<AppLanguage?>>[
                      _Choice(value: null, label: l10n.settingsThemeSystem),
                      // Each language is named in itself, so a reader who has
                      // landed in the wrong one can still read the way out.
                      for (final option in AppLanguage.values)
                        _Choice(value: option, label: option.endonym),
                    ],
                  ),

                  _GroupLabel(text: l10n.settingsTheme),
                  _ChoicePanel<ThemeMode>(
                    selected: settings.themeMode,
                    onChanged: (mode) {
                      if (mode != null) controller.setThemeMode(mode);
                    },
                    options: <_Choice<ThemeMode>>[
                      _Choice(
                        value: ThemeMode.system,
                        label: l10n.settingsThemeSystem,
                        icon: Icons.brightness_auto_outlined,
                      ),
                      _Choice(
                        value: ThemeMode.light,
                        label: l10n.settingsThemeLight,
                        icon: Icons.light_mode_outlined,
                      ),
                      _Choice(
                        value: ThemeMode.dark,
                        label: l10n.settingsThemeDark,
                        icon: Icons.dark_mode_outlined,
                      ),
                    ],
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
                  _ChoicePanel<LearningLevel>(
                    selected: settings.readingLevel,
                    onChanged: (level) {
                      if (level != null) controller.setReadingLevel(level);
                    },
                    options: <_Choice<LearningLevel>>[
                      for (final level in LearningLevel.values)
                        _Choice(
                          value: level,
                          label: TaxonomyLabels.level(level).resolve(language),
                          detail: TaxonomyLabels.depth(level.defaultDepth)
                              .resolve(language),
                        ),
                    ],
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

/// One option inside a [_ChoicePanel].
class _Choice<T> {
  const _Choice({
    required this.value,
    required this.label,
    this.detail,
    this.icon,
  });

  final T value;
  final String label;

  /// A second line, for a choice whose name does not explain itself.
  final String? detail;

  final IconData? icon;
}

/// A group of mutually exclusive settings, drawn the way the rest of the app
/// draws things.
///
/// ## Why not `RadioListTile`
///
/// Because it was the one screen that did not look like the product. Every
/// other surface here is a glass panel with a hairline and a lit accent;
/// Settings was a column of bare Material radios on a flat background, which is
/// what a form looks like before anyone has designed it.
///
/// The selection is shown three times over — an ember wash, a hairline in the
/// accent, and a bloom underneath — because that is how selection reads
/// everywhere else in the app, on the navigation pill and on the depth control.
/// A reader should not have to learn a second visual language for the settings
/// screen.
///
/// The radio itself stays. It is what makes the group announce itself as "one
/// of four, second selected" to a screen reader, and a row of tappable
/// rectangles does not.
class _ChoicePanel<T> extends StatelessWidget {
  const _ChoicePanel({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<_Choice<T>> options;
  final T selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: GlassPanel(
        padding: const EdgeInsets.all(Spacing.xs),
        child: RadioGroup<T>(
          groupValue: selected,
          onChanged: onChanged,
          child: Column(
            children: <Widget>[
              for (final (index, option) in options.indexed)
                EntranceAnimation(
                  index: index,
                  // A shorter rise than a list of cards. These rows are already
                  // close together, and the full 16 pixels made the panel look
                  // like it was assembling itself.
                  distance: 8,
                  child: _ChoiceRow<T>(
                    option: option,
                    selected: option.value == selected,
                    onTap: () => onChanged(option.value),
                    theme: theme,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final _Choice<T> option;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final detail = option.detail;
    final icon = option.icon;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xxs),
      child: AnimatedContainer(
        duration: Motion.duration(context, MotionTokens.quick),
        curve: MotionTokens.standard,
        decoration: BoxDecoration(
          borderRadius: Radii.cardRadius,
          color: selected
              ? scheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? Glass.glow(scheme.primary, strength: 0.45)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: Radii.cardRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  // Excluded from semantics: the radio below already announces
                  // the state, and a screen reader that says "selected" twice
                  // for one row is worse than one that says it once.
                  ExcludeSemantics(child: Radio<T>(value: option.value)),
                  if (icon != null) ...<Widget>[
                    Icon(
                      icon,
                      size: 18,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          option.label,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        if (detail != null)
                          Text(
                            detail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
