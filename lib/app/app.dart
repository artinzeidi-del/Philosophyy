import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/core/design/app_theme.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The application root.
///
/// The theme is rebuilt when the language changes, because the type scale is
/// language-dependent — Persian and Latin need different sizes and leading to
/// read at the same optical weight. Text direction is not set here: the
/// [Locale] handed to [MaterialApp] drives it, so every widget in the tree gets
/// the right direction without anyone having to remember to ask for it.
class PhilosophiaApp extends ConsumerWidget {
  const PhilosophiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
final routerProvider = Provider<GoRouter>((ref) => AppRouter.build());
