import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/playback/video_player_screen.dart';

void main() {
  test('a held seek key starts gently and rises slowly to a ceiling', () {
    expect(holdSeekSpeed(const Duration(milliseconds: 300)), 20);
    expect(holdSeekSpeed(const Duration(milliseconds: 1500)), 20);
    expect(holdSeekSpeed(const Duration(seconds: 3)), 40);
    expect(holdSeekSpeed(const Duration(seconds: 5)), 90);
    expect(holdSeekSpeed(const Duration(seconds: 7)), 180);
    expect(holdSeekSpeed(const Duration(seconds: 9)), 300);
    expect(holdSeekSpeed(const Duration(seconds: 60)), 300, reason: 'a ceiling');
    // Never slower the longer it is held.
    var last = 0.0;
    for (var ms = 0; ms <= 8000; ms += 250) {
      final v = holdSeekSpeed(Duration(milliseconds: ms));
      expect(v, greaterThanOrEqualTo(last));
      last = v;
    }
  });
}
