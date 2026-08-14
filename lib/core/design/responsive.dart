import 'package:flutter/widgets.dart';
import 'package:philosophyy/core/design/design_tokens.dart';

/// How wide the window is, in the terms the layout actually cares about.
///
/// Three sizes rather than a spectrum, because the decisions the product makes
/// are discrete: where the navigation lives, how many cards fit in a row, and
/// how much of a summary is worth showing. A continuous function of width would
/// give the illusion of more control and be harder to reason about.
enum WindowSize {
  /// A phone, or a narrow split-screen pane.
  compact,

  /// A tablet, a large phone in landscape, or a small window.
  medium,

  /// A desktop window with room for navigation, content and margin.
  expanded;

  /// The size for a given width in logical pixels.
  static WindowSize of(double width) {
    if (width < Breakpoints.compact) return WindowSize.compact;
    if (width < Breakpoints.expanded) return WindowSize.medium;
    return WindowSize.expanded;
  }

  /// Whether this is a phone-shaped window.
  bool get isCompact => this == WindowSize.compact;
}

/// The layout decisions that depend on how much room there is.
///
/// ## Why this exists rather than a `MediaQuery` call at each site
///
/// The breakpoints were defined for three sessions and used by nothing: every
/// screen laid itself out in one narrow column and put a bottom bar under it,
/// so a tablet showed a strip of content down the middle with two thirds of the
/// glass empty, and a desktop showed the same strip with five navigation
/// destinations stretched across a metre. Constants nobody consults are not a
/// responsive design — they are a note saying somebody meant to build one.
///
/// Gathering the decisions here means a new screen gets them by asking rather
/// than by remembering, and means the answers can be tested directly.
abstract final class ResponsiveLayout {
  /// The window size for [context].
  ///
  /// Reads the nearest `MediaQuery`, which inside the shell is the space the
  /// content has after the navigation rail has taken its share — so a screen
  /// asking this gets its own width, not the window's.
  static WindowSize sizeOf(BuildContext context) =>
      WindowSize.of(MediaQuery.sizeOf(context).width);

  /// How many cards fit in a row.
  ///
  /// One on a phone. Two on a tablet, which is as many as a card carrying a
  /// title, a date and a sentence can hold without the sentence becoming a
  /// column of two words. Three on a desktop.
  static int columnsFor(BuildContext context) => switch (sizeOf(context)) {
    WindowSize.compact => 1,
    WindowSize.medium => 2,
    WindowSize.expanded => 3,
  };

  /// How many lines of summary a card shows, or `null` for no limit.
  ///
  /// Null in a single column, where a card is as tall as its text and nothing
  /// has to line up. In a grid every card in a row is the same height, so the
  /// summary is clamped and the ragged edge disappears.
  ///
  /// Three rather than two: at two, summaries were losing their last few words
  /// to an ellipsis that the card had room for. A clamp should be the rare
  /// case, not the usual one.
  static int? summaryLines(BuildContext context) =>
      columnsFor(context) == 1 ? null : 3;

  /// The widest a run of cards should be allowed to get.
  ///
  /// Cards are not body text and do not need the reading measure, but they do
  /// need a limit: a card stretched across a wide monitor puts its date at one
  /// end of the eye's travel and its summary at the other.
  static double contentWidthFor(BuildContext context) =>
      sizeOf(context).isCompact ? double.infinity : Breakpoints.contentMaxWidth;

  /// Horizontal padding around a screen's content.
  ///
  /// A phone needs the content close to the edges; a wide window can afford to
  /// let it breathe, and looks unfinished if it does not.
  static double gutterFor(BuildContext context) => switch (sizeOf(context)) {
    WindowSize.compact => Spacing.lg,
    WindowSize.medium => Spacing.xl,
    WindowSize.expanded => Spacing.xxl,
  };
}

/// Centres its child and stops it growing past the content maximum.
///
/// Distinct from `ReadingColumn`, which holds prose to a much narrower measure.
/// Cards, grids and controls use this one.
class ContentColumn extends StatelessWidget {
  const ContentColumn({required this.child, super.key});

  /// The content to constrain.
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: ResponsiveLayout.contentWidthFor(context),
      ),
      child: child,
    ),
  );
}
