import 'package:flutter/material.dart';

/// Marks a piece of the interface as ornament rather than content.
///
/// ## Why this is its own widget
///
/// WCAG exempts "pure decoration" from the contrast requirement, and the app
/// has exactly one piece of it: the oversized quotation mark set very faint
/// behind a quote. It says *these are somebody's words* before a word is read,
/// and it is meant to be barely there — held to 4.5:1 it would have to be dark
/// enough to compete with the quotation itself, which is the opposite of what
/// it is for.
///
/// The painted-contrast check in `test/support` needs to know that. The obvious
/// signal is `ExcludeSemantics`, and using it was a mistake twice over.
/// Flutter's own `Icon` wraps every glyph in one, so the check quietly stopped
/// measuring every icon in the app; and the navigation bar excludes its label
/// only so a screen reader does not announce the same destination twice — that
/// label is text a reader reads, and it is exactly the kind of pairing the
/// check exists to catch.
///
/// So ornament is declared rather than inferred. A widget that is decoration
/// says so here, once, and both the accessibility tree and the contrast check
/// read the same statement.
class Decorative extends StatelessWidget {
  const Decorative({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: child);
}
