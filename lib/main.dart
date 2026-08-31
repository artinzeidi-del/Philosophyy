import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/data/user/stored_user_data_repository.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _registerBundledFontLicences();

  // Nothing between here and the first frame may stop the app from opening.
  // Every step below has a working answer for its own failure, because the
  // alternative is what this used to do: throw before `runApp` and leave the
  // reader looking at a blank window with nothing in it to explain itself.
  final store = await _openStore();

  // The reader's own work is loaded before the first frame for the same reason
  // as the preferences: a bookmark that appears a frame after the article does
  // looks like a bug, and a library screen that flashes empty before filling
  // looks like data loss.
  //
  // `load` is written not to throw — an unreadable library opens empty — but
  // it is caught anyway. This is the last thing standing between a defect
  // anywhere below and an app that does not start.
  var library = UserLibrary.empty;
  try {
    library = await StoredUserDataRepository(store).load();
  } on Object catch (error, stack) {
    debugPrint('The saved library could not be opened: $error');
    assert(() {
      debugPrintStack(stackTrace: stack);
      return true;
    }());
  }

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        initialLibraryProvider.overrideWithValue(library),
      ],
      child: const PhilosophiaApp(),
    ),
  );
}

/// Opens the device's preferences, or memory if the device will not open them.
///
/// Preferences are read before the first frame so the app opens directly in the
/// reader's theme and language; deferring it would show one frame of the wrong
/// theme, which is small but looks broken every single launch.
///
/// A device can refuse — a browser with site storage turned off does, and so
/// does an Android install whose preferences file has been corrupted. That is
/// worth a session that remembers nothing. It is not worth an app that does not
/// open, which is what refusing here used to cost.
Future<KeyValueStore> _openStore() async {
  try {
    return PreferencesStore(await SharedPreferences.getInstance());
  } on Object catch (error, stack) {
    debugPrint(
      'This device would not open its stored preferences, so this session '
      'will not remember anything: $error',
    );
    assert(() {
      debugPrintStack(stackTrace: stack);
      return true;
    }());
    return InMemoryStore();
  }
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

    final hebrew = await rootBundle.loadString(
      'assets/fonts/notoserifhebrew/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Serif Hebrew',
    ], hebrew);

    final ethiopic = await rootBundle.loadString(
      'assets/fonts/notoserifethiopic/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Serif Ethiopic',
    ], ethiopic);

    final tibetan = await rootBundle.loadString(
      'assets/fonts/notoseriftibetan/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Serif Tibetan',
    ], tibetan);

    final bengali = await rootBundle.loadString(
      'assets/fonts/notoserifbengali/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Serif Bengali',
    ], bengali);

    final hieroglyphs = await rootBundle.loadString(
      'assets/fonts/notosansegyptianhieroglyphs/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const <String>[
      'Noto Sans Egyptian Hieroglyphs',
    ], hieroglyphs);
  });
}

/// Whether the app is running in a release build, exposed for code that must
/// behave differently in production without reaching for `assert` tricks.
const bool isReleaseBuild = kReleaseMode;
