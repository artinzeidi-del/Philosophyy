import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/data/user/stored_user_data_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerBundledFontLicences();

  // Preferences are loaded before the first frame so the app opens directly in
  // the reader's theme and language. Deferring this would show one frame of the
  // wrong theme, which is small but looks broken every single launch.
  final preferences = await SharedPreferences.getInstance();

  // The reader's own work is loaded before the first frame for the same reason:
  // a bookmark that appears a frame after the article does looks like a bug, and
  // a library screen that flashes empty before filling looks like data loss.
  final userData = StoredUserDataRepository(PreferencesStore(preferences));
  final library = await userData.load();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialLibraryProvider.overrideWithValue(library),
      ],
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

    final naskh = await rootBundle.loadString(
      'assets/fonts/notonaskharabic/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Naskh Arabic',
    ], naskh);

    final greek = await rootBundle.loadString('assets/fonts/gfsdidot/OFL.txt');
    yield LicenseEntryWithLineBreaks(const <String>['GFS Didot'], greek);

    final cjk = await rootBundle.loadString(
      'assets/fonts/notoserifcjk/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Serif CJK (SC, JP, KR)',
    ], cjk);

    final devanagari = await rootBundle.loadString(
      'assets/fonts/notoserifdevanagari/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Serif Devanagari',
    ], devanagari);
  });
}

/// Whether the app is running in a release build, exposed for code that must
/// behave differently in production without reaching for `assert` tricks.
const bool isReleaseBuild = kReleaseMode;
