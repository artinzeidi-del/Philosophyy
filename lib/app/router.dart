import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/features/entity/entity_screen.dart';
import 'package:philosophyy/features/explore/explore_screen.dart';
import 'package:philosophyy/features/home/home_screen.dart';
import 'package:philosophyy/features/library/library_screen.dart';
import 'package:philosophyy/features/search/search_screen.dart';
import 'package:philosophyy/features/settings/settings_screen.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The app's navigation.
///
/// Entity routes are derived from [EntityKind.routeSegment] rather than written
/// out, so a new entity kind cannot be added with a route that disagrees with
/// the one [EntityRef.route] generates. That mismatch is invisible until a
/// reader taps a link and lands nowhere, which is why it is closed off here
/// rather than trusted to review.
class AppRouter {
  /// Builds the router.
  static GoRouter build() => GoRouter(
    initialLocation: home,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _ShellScaffold(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: explore,
                // The axis and term ride in the query string rather than in
                // shared state, so a link to "aesthetics" is a link and can be
                // followed, restored and shared like any other.
                builder: (context, state) => ExploreScreen(
                  key: ValueKey<String>(state.uri.toString()),
                  initialAxis: state.uri.queryParameters['axis'],
                  initialTermId: state.uri.queryParameters['term'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: search,
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: library,
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Article routes sit outside the shell so that reading fills the screen
      // and the navigation bar does not compete with the text.
      for (final kind in _articleKinds)
        GoRoute(
          path: '/${kind.routeSegment}/:id',
          pageBuilder: (context, state) => CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: MotionTokens.moderate,
            reverseTransitionDuration: MotionTokens.quick,
            transitionsBuilder: PageTransitions.article,
            child: EntityScreen(
              kind: kind,
              id: state.pathParameters['id'] ?? '',
            ),
          ),
        ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );

  /// The home tab.
  static const String home = '/';

  /// The browse tab.
  static const String explore = '/explore';

  /// The search tab.
  static const String search = '/search';

  /// The reader's saved work.
  static const String library = '/library';

  /// The settings tab.
  static const String settings = '/settings';

  /// The entity kinds that have an article screen.
  ///
  /// Quotations, arguments and sources are shown inside other articles rather
  /// than on pages of their own, so they are excluded here — and because the
  /// list is derived from the enum, adding a kind without deciding this is not
  /// possible.
  static const List<EntityKind> _articleKinds = <EntityKind>[
    EntityKind.philosopher,
    EntityKind.concept,
    EntityKind.work,
    EntityKind.school,
  ];

  /// The article kinds, exposed for tests that check every kind is routable.
  static List<EntityKind> get articleKinds => _articleKinds;
}

/// A navigation destination, declared once and rendered as whichever control
/// the window is wide enough for.
///
/// Declaring them in one list rather than twice is what keeps the bar and the
/// rail from drifting apart — the failure mode being a destination that exists
/// on a phone and quietly does not on a tablet.
class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  List<_Destination> _destinations(AppL10n l10n) => <_Destination>[
    _Destination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: l10n.navHome,
    ),
    _Destination(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: l10n.navExplore,
    ),
    _Destination(
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
      label: l10n.navSearch,
    ),
    _Destination(
      icon: Icons.bookmark_border,
      selectedIcon: Icons.bookmark,
      label: l10n.navLibrary,
    ),
    _Destination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: l10n.navSettings,
    ),
  ];

  void _go(int index) => navigationShell.goBranch(
    index,
    // Tapping the tab you are already on returns it to its root, which is what
    // every platform's navigation does and what readers expect.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final destinations = _destinations(l10n);

    // LayoutBuilder rather than MediaQuery: it reports the space this widget
    // actually has, which is the same thing on a phone and not the same thing
    // inside a split-screen or a resized desktop window.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < Breakpoints.compact) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _go,
              destinations: <NavigationDestination>[
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            ),
          );
        }

        // A bottom bar on a tablet puts the controls as far from the hand
        // holding it as the screen allows, and on a desktop it stretches five
        // destinations across a metre of glass. Above the phone breakpoint the
        // navigation moves to the side, and above the wide breakpoint it has
        // room to carry its labels inline.
        final extended = width >= Breakpoints.expanded;
        return Scaffold(
          body: Row(
            children: <Widget>[
              _Rail(
                destinations: destinations,
                selectedIndex: navigationShell.currentIndex,
                onSelected: _go,
                extended: extended,
              ),
              Expanded(child: navigationShell),
            ],
          ),
        );
      },
    );
  }
}

/// The side navigation, with the width change animated rather than snapped.
///
/// `NavigationRail` rebuilds at a new width when `extended` flips, which on a
/// window drag reads as the whole page jumping sideways. Animating the width
/// and cross-fading the labels turns a resize into a movement the eye can
/// follow.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.extended,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

  /// Wide enough for the longest destination label at the label style.
  ///
  /// Measured rather than guessed: "Settings" needs 93 logical pixels and
  /// Persian's «تنظیمات» is wider still, so 88 and then 104 both truncated to
  /// "Setti…". A collapsed rail is meant to be narrow, but not so narrow that
  /// it stops naming where it goes.
  static const double _collapsedWidth = 132;
  static const double _extendedWidth = 220;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: MotionTokens.moderate,
      curve: MotionTokens.standard,
      width: extended ? _extendedWidth : _collapsedWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: BorderDirectional(
          end: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        right: false,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            // The rail must be at least as tall as the window or its
            // destinations bunch at the top; the scroll view is there for the
            // short-window case, which is a landscape phone.
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height - Spacing.xxl,
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: Spacing.xl),
                for (final (index, destination) in destinations.indexed)
                  _RailDestination(
                    destination: destination,
                    selected: index == selectedIndex,
                    extended: extended,
                    onTap: () => onSelected(index),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailDestination extends StatefulWidget {
  const _RailDestination({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  State<_RailDestination> createState() => _RailDestinationState();
}

class _RailDestinationState extends State<_RailDestination> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = widget.selected;
    final reduced = Motion.isReduced(context);

    final background = selected
        ? scheme.secondaryContainer
        : _hovered
        ? scheme.surfaceContainerHigh
        : Colors.transparent;
    final foreground = selected
        ? scheme.onSecondaryContainer
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xxs,
      ),
      child: Semantics(
        button: true,
        selected: selected,
        label: widget.destination.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: reduced ? Duration.zero : MotionTokens.quick,
              curve: MotionTokens.standard,
              padding: EdgeInsets.symmetric(
                horizontal: widget.extended ? Spacing.md : Spacing.xs,
                vertical: widget.extended ? Spacing.md : Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
              ),
              // The label is shown at every width, stacked under the icon when
              // the rail is narrow. An icon-only rail asks the reader to learn
              // five glyphs before they can navigate, and the bottom bar this
              // replaced on small screens never asked that.
              child: widget.extended
                  ? Row(
                      children: <Widget>[
                        _icon(foreground, selected, reduced),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Text(
                            widget.destination.label,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _icon(foreground, selected, reduced),
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          widget.destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: foreground,
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

  /// The destination's icon, cross-faded between its states.
  ///
  /// Switched rather than swapped so that moving between sections reads as one
  /// control changing state, not two icons replacing each other.
  Widget _icon(Color colour, bool selected, bool reduced) => AnimatedSwitcher(
    duration: reduced ? Duration.zero : MotionTokens.quick,
    child: Icon(
      selected ? widget.destination.selectedIcon : widget.destination.icon,
      key: ValueKey<bool>(selected),
      color: colour,
      size: 22,
    ),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        icon: Icons.link_off,
        title: l10n.notFoundTitle,
        body: l10n.notFoundBody,
        action: FilledButton(
          onPressed: () => context.go(AppRouter.home),
          child: Text(l10n.backToHome),
        ),
      ),
    );
  }
}
