import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/ui/screens/playback/video_player_screen.dart';

void main() {
  test('a held seek key starts slow and speeds up', () {
    expect(holdSeekSpeed(const Duration(milliseconds: 300)), 30);
    expect(holdSeekSpeed(const Duration(milliseconds: 1500)), 60);
    expect(holdSeekSpeed(const Duration(seconds: 3)), 120);
    expect(holdSeekSpeed(const Duration(seconds: 4)), 300);
    expect(holdSeekSpeed(const Duration(seconds: 9)), 600);
    // Never slower the longer it is held.
    var last = 0.0;
    for (var ms = 0; ms <= 8000; ms += 250) {
      final v = holdSeekSpeed(Duration(milliseconds: ms));
      expect(v, greaterThanOrEqualTo(last));
      last = v;
    }
  });
}
