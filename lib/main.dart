import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerBundledFontLicences();

  // Preferences are loaded before the first frame so the app opens directly in
  // the reader's theme and language. Deferring this would show one frame of the
  // wrong theme, which is small but looks broken every single launch.
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const PhilosophiaApp(),
    ),
  );
}

/// Declares the licences of the fonts bundled with the app.
///
/// Flutter collects licences automatically for packages, but fonts added as
/// assets are invisible to it. All three bundled families are SIL OFL 1.1, which
/// requires the licence to travel with the software — so it is registered here
/// and shown in the about screen rather than left as an unmet obligation.
void _registerBundledFontLicences() {
  LicenseRegistry.addLicense(() async* {
    final vazirmatn = await rootBundle.loadString(
      'assets/fonts/vazirmatn/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>['Vazirmatn'], vazirmatn);

    final spectral = await rootBundle.loadString(
      'assets/fonts/spectral/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>['Spectral'], spectral);

    final greek = await rootBundle.loadString('assets/fonts/gfsdidot/OFL.txt');
    yield LicenseEntryWithLineBreaks(const <String>['GFS Didot'], greek);
  });
}

/// Whether the app is running in a release build, exposed for code that must
/// behave differently in production without reaching for `assert` tricks.
const bool isReleaseBuild = kReleaseMode;
