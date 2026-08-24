import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The control that takes the reader off a page and back into the app.
///
/// Pops when there is something to pop, and goes to the home screen when there
/// is not. That second case is the whole reason this exists. Articles, the
/// glossary, the primer and the quiz sit outside the navigation shell so that a
/// row of tabs does not compete with a page of prose — which is right when the
/// reader walked there, because the app bar then carries a back arrow.
///
/// It is wrong when they did not walk there. A shared link to an article, or a
/// reload of the page being read, makes that route the first entry in the
/// history: `Navigator.canPop` is false, `AppBar` draws nothing, and the screen
/// has no navigation bar either. The reader is left on a page with no way off
/// it that belongs to the app. A link to one article is the thing people send
/// each other, so that is the most likely way a new reader arrives.
class UpButton extends StatelessWidget {
  const UpButton({super.key, this.color});

  /// Ink colour, for a bar that sets its own foreground.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // `maybeOf`, because a screen can be mounted without a router around it —
    // a widget test pumping one page on its own does exactly that, and
    // `GoRouter.of` throws rather than returning null. An app bar is not worth
    // crashing a screen over.
    final router = GoRouter.maybeOf(context);

    final canPop = router?.canPop() ?? Navigator.of(context).canPop();
    if (canPop) return BackButton(color: color);

    // Nothing to pop and no router to send anywhere: there is no destination
    // to offer, so offer nothing rather than a control that does nothing.
    if (router == null) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.home_outlined),
      color: color,
      tooltip: AppL10n.of(context).navHome,
      onPressed: () => router.go(AppRouter.home),
    );
  }
}
