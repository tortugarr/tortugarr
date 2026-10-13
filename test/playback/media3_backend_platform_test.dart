import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin/playback/media3_player_backend.dart';
import 'package:moonfin/preference/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // EventChannel sends the first listen inside its own try and hands a failure
  // to FlutterError rather than to the stream, so the subscription's onError
  // never sees this and it surfaces as an uncaught error. That is why the
  // playback module builds this backend on Android alone.
  test(
    'building it without the plugin raises where nothing can catch it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PreferenceStore();
      await store.init();

      final reported = Completer<String>();
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!reported.isCompleted) {
          reported.complete(details.exceptionAsString());
        }
      };
      addTearDown(() => FlutterError.onError = previous);

      Media3PlayerBackend(UserPreferences(store));

      expect(
        await reported.future.timeout(const Duration(seconds: 5)),
        contains('moonfin/media3_video_events'),
      );
    },
  );
}
