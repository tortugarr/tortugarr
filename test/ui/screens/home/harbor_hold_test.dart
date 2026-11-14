import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/home/harbor_hold.dart';

void main() {
  group('HarborHold', () {
    late List<int> steps;
    late int releases;
    late int limit;

    HarborHold make({int max = 1000}) {
      steps = [];
      releases = 0;
      limit = max;
      return HarborHold(
        onStep: (d) {
          if (steps.length >= limit) return false;
          steps.add(d);
          return true;
        },
        onRelease: () => releases++,
      );
    }

    test('a tap moves exactly one step', () {
      fakeAsync((async) {
        final hold = make();
        hold.press(1);
        async.elapse(const Duration(milliseconds: 120));
        hold.release();
        async.elapse(const Duration(seconds: 2));
        expect(steps, [1]);
        expect(releases, 1);
        expect(hold.holding, isFalse);
      });
    });

    test('holding glides by itself and stops on release', () {
      fakeAsync((async) {
        final hold = make();
        hold.press(-1);
        async.elapse(const Duration(milliseconds: 1500));
        expect(hold.gliding, isTrue);
        final held = steps.length;
        expect(held, greaterThan(5));
        expect(steps.every((d) => d == -1), isTrue);
        hold.release();
        async.elapse(const Duration(seconds: 2));
        expect(steps.length, held);
      });
    });

    test('the glide speeds up the longer it is held', () {
      fakeAsync((async) {
        final hold = make();
        hold.press(1);
        async.elapse(const Duration(milliseconds: 1320));
        final firstSecond = steps.length;
        async.elapse(const Duration(seconds: 1));
        final laterSecond = steps.length - firstSecond;
        async.elapse(const Duration(seconds: 1));
        final thirdSecond = steps.length - firstSecond - laterSecond;
        expect(laterSecond, greaterThan(6));
        expect(thirdSecond, greaterThanOrEqualTo(laterSecond));
        expect(hold.interval, hold.endInterval);
        hold.release();
      });
    });

    test('remote key repeats in the same direction add no steps', () {
      fakeAsync((async) {
        final hold = make();
        hold.press(1);
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 40));
          hold.press(1);
        }
        expect(steps, [1]);
        hold.release();
      });
    });

    test('stops at the end and still reports the release', () {
      fakeAsync((async) {
        final hold = make(max: 3);
        hold.press(1);
        async.elapse(const Duration(seconds: 3));
        expect(steps.length, 3);
        hold.release();
        expect(releases, 1);
      });
    });

    test('a brake drops the glide back to its starting speed', () {
      fakeAsync((async) {
        final hold = make();
        hold.press(1);
        async.elapse(const Duration(seconds: 3));
        expect(hold.interval, hold.endInterval);
        hold.brake(Duration.zero);
        expect(hold.interval, hold.startInterval);
        hold.release();
      });
    });

    test('a brake holds the next step back', () {
      fakeAsync((async) {
        final hold = make();
        hold.press(1);
        async.elapse(hold.delay);
        expect(steps.length, 2);
        hold.brake(const Duration(milliseconds: 400));
        // The stop is taken after the step that is due next.
        async.elapse(hold.startInterval);
        final atPause = steps.length;
        async.elapse(const Duration(milliseconds: 300));
        expect(steps.length, atPause);
        async.elapse(const Duration(milliseconds: 300));
        expect(steps.length, greaterThan(atPause));
        hold.release();
      });
    });

    test('a new direction starts over with one step', () {
      fakeAsync((async) {
        final hold = make();
        hold.press(1);
        async.elapse(const Duration(seconds: 1));
        steps.clear();
        hold.press(-1);
        expect(steps, [-1]);
        async.elapse(const Duration(milliseconds: 100));
        expect(steps, [-1]);
        hold.release();
      });
    });
  });
}
