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
                builder: (context, state) => const ExploreScreen(),
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

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the tab you are already on returns it to its root, which is
          // what every platform's navigation does and what readers expect.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            selectedIcon: const Icon(Icons.explore),
            label: l10n.navExplore,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: l10n.navSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_border),
            selectedIcon: const Icon(Icons.bookmark),
            label: l10n.navLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
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
