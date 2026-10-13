import 'package:flutter_test/flutter_test.dart';
import 'package:playback_core/playback_core.dart';

const _probe = Duration(milliseconds: 10);
const _target = Duration(minutes: 5, seconds: 18);

void main() {
  test('a seek that lands and holds is confirmed', () async {
    expect(
      await confirmSeekHeld(_target, () => _target, probeInterval: _probe),
      isTrue,
    );
  });

  test('the in flight echo alone does not count', () async {
    // mpv reports the target while the seek is pending, then reverts to the
    // start when the seek quietly fails.
    var reads = 0;
    Duration position() => ++reads <= 1 ? _target : Duration.zero;

    expect(
      await confirmSeekHeld(_target, position, probeInterval: _probe),
      isFalse,
    );
  });

  test('a seek that lands after a few reads is confirmed', () async {
    var reads = 0;
    Duration position() => ++reads <= 4 ? Duration.zero : _target;

    expect(
      await confirmSeekHeld(_target, position, probeInterval: _probe),
      isTrue,
    );
  });

  test('a seek that never lands is refused within its probe budget', () async {
    expect(
      await confirmSeekHeld(
        _target,
        () => Duration.zero,
        probeInterval: _probe,
      ),
      isFalse,
    );
  });

  test('landing near the target counts, streams seek to keyframes', () async {
    expect(
      await confirmSeekHeld(
        _target,
        () => _target - const Duration(seconds: 6),
        probeInterval: _probe,
      ),
      isTrue,
    );
  });
}
