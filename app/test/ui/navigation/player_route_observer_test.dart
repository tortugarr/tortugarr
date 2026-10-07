import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/navigation/app_router.dart';

// Guards the contract the Android TV surface fix depends on: the fullscreen
// player routes (built via pageBuilder, whose page name PlayerRouteObserver
// matches) must flip isPlayerActive so the media bar keeps its Media3 preview
// unmounted while a player is on screen.
Route<dynamic> _route(String? name) =>
    PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (_, a, b) => const SizedBox.shrink(),
    );

void main() {
  test('player routes flip isPlayerActive; others do not', () {
    final observer = PlayerRouteObserver();
    expect(observer.isPlayerActive.value, isFalse);

    final video = _route('/player/video');
    observer.didPush(video, null);
    expect(observer.isPlayerActive.value, isTrue);

    observer.didPop(video, null);
    expect(observer.isPlayerActive.value, isFalse);

    final game = _route('/game-player/lib1/game1');
    observer.didPush(game, null);
    expect(observer.isPlayerActive.value, isTrue);
    observer.didPop(game, null);
    expect(observer.isPlayerActive.value, isFalse);
  });

  test('non-player and unnamed routes leave isPlayerActive false', () {
    final observer = PlayerRouteObserver();

    observer.didPush(_route('/home'), null);
    expect(observer.isPlayerActive.value, isFalse);

    observer.didPush(_route(null), null);
    expect(observer.isPlayerActive.value, isFalse);
  });

  test('nested player routes stay active until the last pops', () {
    final observer = PlayerRouteObserver();
    final audio = _route('/player/audio');
    final video = _route('/player/video');

    observer.didPush(audio, null);
    observer.didPush(video, null);
    expect(observer.isPlayerActive.value, isTrue);

    observer.didPop(video, null);
    expect(observer.isPlayerActive.value, isTrue);

    observer.didPop(audio, null);
    expect(observer.isPlayerActive.value, isFalse);
  });
}
