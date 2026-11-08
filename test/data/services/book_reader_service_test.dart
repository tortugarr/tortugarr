import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/book_reader_service.dart';

AggregatedItem _book(Map<String, dynamic> raw) =>
    AggregatedItem(id: 'b1', serverId: 's1', rawData: {'Type': 'Book', ...raw});

void main() {
  test('a # in a file path is part of the name, not a URI fragment', () {
    final item = _book({'Path': '/comics/Batman #12.cbz'});

    expect(BookReaderService.detectExtension(item), 'cbz');
    expect(BookReaderService.fileName(item), 'Batman #12.cbz');
  });

  test('the file name comes from a Windows path too', () {
    final item = _book({'Path': r'D:\Books\Dune.epub'});

    expect(BookReaderService.fileName(item), 'Dune.epub');
    expect(BookReaderService.detectExtension(item), 'epub');
  });

  group('newerServerPageIndex', () {
    AggregatedItem progress(int ticks, [String? lastPlayed]) => _book({
      'UserData': {
        'PlaybackPositionTicks': ticks,
        'LastPlayedDate': ?lastPlayed,
      },
    });
    final localSave = DateTime.utc(2026, 10, 17, 12);

    test('reads the page index on the jellyfin-web scale', () {
      expect(BookReaderService.newerServerPageIndex(progress(30000)), 3);
    });

    test('a book with no server position has no server page', () {
      expect(BookReaderService.newerServerPageIndex(progress(0)), isNull);
    });

    test('a later save on another device wins, even going backwards', () {
      final item = progress(20000, '2026-10-17T12:05:00.0000000Z');

      expect(
        BookReaderService.newerServerPageIndex(item, localSavedAt: localSave),
        2,
      );
    });

    test("this device's later save wins over an older server position", () {
      final item = progress(90000, '2026-10-17T11:55:00.0000000Z');

      expect(
        BookReaderService.newerServerPageIndex(item, localSavedAt: localSave),
        isNull,
      );
    });

    test('an undated server position loses to a dated local save', () {
      expect(
        BookReaderService.newerServerPageIndex(
          progress(90000),
          localSavedAt: localSave,
        ),
        isNull,
      );
    });
  });

  group('EPUB progress', () {
    AggregatedItem progress(int ticks, [String? lastPlayed]) => _book({
      'UserData': {
        'PlaybackPositionTicks': ticks,
        'LastPlayedDate': ?lastPlayed,
      },
    });
    final localSave = DateTime.utc(2026, 10, 17, 12);

    test('ticks are the fraction of one second, clamped', () {
      expect(BookReaderService.epubTicks(0), 0);
      expect(BookReaderService.epubTicks(0.25), 2500000);
      expect(BookReaderService.epubTicks(1), 10000000);
      expect(BookReaderService.epubTicks(1.4), 10000000);
      expect(BookReaderService.epubTicks(-0.2), 0);
    });

    test('a saved location comes back through epub.js percentages', () {
      // epub.js reports location / total and restores ceil(total * fraction).
      for (final total in [1, 7, 300, 1023, 4096, 25000]) {
        for (var location = 0; location <= total; location++) {
          final ticks = BookReaderService.epubTicks(location / total);
          final restored = (total * ticks / BookReaderService.epubTicksPerBook)
              .ceil();
          expect(restored, location, reason: '$location of $total');
        }
      }
    });

    test('reads the server fraction when there is no local place', () {
      expect(
        BookReaderService.newerServerEpubFraction(progress(2500000)),
        0.25,
      );
      expect(BookReaderService.newerServerEpubFraction(progress(0)), isNull);
    });

    test('a server position past the end reads as the end', () {
      expect(BookReaderService.newerServerEpubFraction(progress(12000000)), 1);
    });

    test('a later save on another device wins', () {
      final item = progress(4000000, '2026-10-17T12:05:00.0000000Z');

      expect(
        BookReaderService.newerServerEpubFraction(
          item,
          localTicks: 6000000,
          localSavedAt: localSave,
        ),
        0.4,
      );
    });

    test('the position this device reported keeps its exact place', () {
      // The report itself stamps the server a moment after the local save.
      final item = progress(6000000, '2026-10-17T12:00:01.0000000Z');

      expect(
        BookReaderService.newerServerEpubFraction(
          item,
          localTicks: 6000000,
          localSavedAt: localSave,
        ),
        isNull,
      );
    });

    test("this device's later save wins over an older server position", () {
      final item = progress(4000000, '2026-10-17T11:55:00.0000000Z');

      expect(
        BookReaderService.newerServerEpubFraction(
          item,
          localTicks: 6000000,
          localSavedAt: localSave,
        ),
        isNull,
      );
    });
  });

  test('falls back to the item name when there is no path', () {
    final item = _book({'Path': '  ', 'Name': 'Dune'});

    expect(BookReaderService.fileName(item), 'Dune');
    expect(BookReaderService.detectExtension(item), isNull);
  });
}
