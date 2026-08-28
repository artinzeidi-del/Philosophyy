import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/core/design/app_theme.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The application root.
///
/// The theme is rebuilt when the language changes, because the type scale is
/// language-dependent — Persian and Latin need different sizes and leading to
/// read at the same optical weight. Text direction is not set here: the
/// [Locale] handed to [MaterialApp] drives it, so every widget in the tree gets
/// the right direction without anyone having to remember to ask for it.
class PhilosophiaApp extends ConsumerStatefulWidget {
  const PhilosophiaApp({super.key});

  @override
  ConsumerState<PhilosophiaApp> createState() => _PhilosophiaAppState();
}

class _PhilosophiaAppState extends ConsumerState<PhilosophiaApp> {
  @override
  void initState() {
    super.initState();
    // The search index is built from the whole corpus and takes long enough
    // that a reader feels it. It used to be built when the search screen
    // appeared, which is better than on the first keystroke and still late:
    // the screen painted and then the isolate stopped, so the field was there
    // and would not accept anything.
    //
    // Building it on the frame after the corpus lands moves the work to a
    // moment the reader is not in: the first screen has painted and they are
    // reading it, not typing. The search screen is then left with nothing to
    // do but draw.
    //
    // Not `scheduleTask` at idle priority, which is what this wants to be and
    // is not reachable: under the test binding an idle task is never served,
    // so every widget test that mounts the app waited on it forever.
    // The corpus is still loading at this point, and an index of nothing is
    // not worth building, so the request waits for it to land and is made
    // once. `fireImmediately` covers the case where it is already there.
    _corpusArrived = ref.listenManual(corpusProvider, (previous, next) {
      if (_warmed || next.value == null) return;
      _warmed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) warmSearchIndex(ref);
      });
    }, fireImmediately: true);
  }

  /// Whether the index has been asked for, so it is asked for once.
  bool _warmed = false;
  ProviderSubscription<AsyncValue<KnowledgeBase>>? _corpusArrived;

  @override
  void dispose() {
    _corpusArrived?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final language = ref.watch(activeLanguageProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppL10n.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: settings.themeMode,
      theme: AppTheme.light(language),
      darkTheme: AppTheme.dark(language),
      locale: settings.language == null
          ? null
          : Locale(settings.language!.code),
      supportedLocales: <Locale>[
        for (final supported in AppLanguage.values) Locale(supported.code),
      ],
      localizationsDelegates: AppL10n.localizationsDelegates,
    );
  }
}

/// Holds the router for the lifetime of the app.
///
/// Kept in a provider rather than constructed in `build` so that a rebuild —
/// which happens on every theme or language change — does not discard the
/// navigation stack the reader is standing on.
final routerProvider = Provider<GoRouter>(
  (ref) => AppRouter.build(initialLocation: ref.watch(initialRouteProvider)),
);

/// Where the app opens.
///
/// Overridden by tests that need to start on a particular screen, and by the
/// platform when the app is launched from a link.
final initialRouteProvider = Provider<String>((ref) => AppRouter.home);
