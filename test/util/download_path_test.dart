import 'package:background_downloader/background_downloader.dart' as bgd;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/download_utils.dart';
import 'package:path/path.dart' as p;

void main() {
  group('splitDownloadPath on Windows', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('keeps the drive so the task cant go relative', () async {
      final (base, directory, filename) = await splitDownloadPath(
        r'C:\Users\someone\Videos\Moonfin/TV/Show/Season 1/Show - S01E01.mkv',
      );

      expect(base, bgd.BaseDirectory.root);
      expect(p.windows.isAbsolute(directory), isTrue);
      expect(directory, r'C:\Users\someone\Videos\Moonfin\TV\Show\Season 1');
      expect(filename, 'Show - S01E01.mkv');
    });

    test('a drive other than C is kept as well', () async {
      final (base, directory, filename) = await splitDownloadPath(
        r'D:\Media\Moonfin\Movies\Film (2020).mkv',
      );

      expect(base, bgd.BaseDirectory.root);
      expect(directory, r'D:\Media\Moonfin\Movies');
      expect(filename, 'Film (2020).mkv');
    });
  });
}
