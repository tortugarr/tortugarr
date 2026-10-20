import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/space_guard_service.dart';

void main() {
  group('driveOfArrPath', () {
    test('reads the drive from /media/Windows<X> mounts', () {
      expect(SpaceGuardService.driveOfArrPath('/media/WindowsH/-= Filmer =-/A'), 'H');
      expect(SpaceGuardService.driveOfArrPath('/media/WindowsE'), 'E');
    });

    test('maps the dedicated container mounts', () {
      expect(SpaceGuardService.driveOfArrPath('/movies/A (2020)'), 'H');
      expect(SpaceGuardService.driveOfArrPath('/tv'), 'H');
    });

    test('does not guess for unknown paths', () {
      expect(SpaceGuardService.driveOfArrPath('/moviesX/A'), isNull);
      expect(SpaceGuardService.driveOfArrPath(''), isNull);
      expect(SpaceGuardService.driveOfArrPath(null), isNull);
    });
  });

  group('SpaceCheck', () {
    const gb = 1024 * 1024 * 1024;

    test('counts the import copy, the buffer and running torrents', () {
      const c = SpaceCheck(
        drive: 'H',
        freeBytes: 29 * gb,
        pendingBytes: 5 * gb,
        releaseBytes: 20 * gb,
      );
      expect(
        c.neededBytes,
        20 * gb * SpaceGuardConfig.importCopyFactor +
            SpaceGuardConfig.bufferBytes,
      );
      expect(c.shortfallBytes, c.neededBytes + 5 * gb - 29 * gb);
    });

    test('has no shortfall when everything fits', () {
      const c = SpaceCheck(
        drive: 'H',
        freeBytes: 500 * gb,
        pendingBytes: 0,
        releaseBytes: 10 * gb,
      );
      expect(c.shortfallBytes, 0);
    });

    test('a manual check without a release needs nothing', () {
      const c = SpaceCheck(
        drive: 'H',
        freeBytes: 1 * gb,
        pendingBytes: 0,
        releaseBytes: 0,
      );
      expect(c.shortfallBytes, 0);
    });
  });
}
