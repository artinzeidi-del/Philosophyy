import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The screen shown while the corpus loads.
///
/// Deliberately quiet: the corpus is bundled with the app, so this is visible
/// for a fraction of a second and a spinner that announces itself would be more
/// disruptive than the wait it covers.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Semantics(
      label: l10n.loading,
      liveRegion: true,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// The screen shown when something failed.
///
/// The reader is told plainly that it is not their fault and given one action.
/// The technical detail goes to [details], which is shown only in debug builds —
/// a stack trace helps a developer and frightens everybody else.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.onRetry, this.details, super.key});

  /// Invoked when the reader asks to try again.
  final VoidCallback onRetry;

  /// Developer-facing detail, surfaced only in debug builds.
  final String? details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.readingMeasure),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l10n.errorTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: Spacing.md),
              Text(
                l10n.errorBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (details != null) ...<Widget>[
                const SizedBox(height: Spacing.lg),
                _DebugOnly(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: Radii.cardRadius,
                    ),
                    child: Text(
                      details!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Spacing.xl),
              FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders its child only in debug builds.
class _DebugOnly extends StatelessWidget {
  const _DebugOnly({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    var isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug ? child : const SizedBox.shrink();
  }
}

/// A screen with nothing to show, which explains what would fill it.
///
/// An empty state that says only "no results" wastes the one moment when the
/// reader is most receptive to being told what to do next.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.title,
    required this.body,
    this.icon,
    this.action,
    super.key,
  });

  /// What is missing.
  final String title;

  /// What the reader can do about it.
  final String body;

  /// An optional illustrative icon.
  final IconData? icon;

  /// An optional way forward.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.readingMeasure),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: Spacing.lg),
              ],
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: Spacing.sm),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: Spacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
