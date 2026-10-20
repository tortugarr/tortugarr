import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/adult_library_service.dart';

void main() {
  const libs = [
    (id: 'a', name: 'Filmer'),
    (id: 'x', name: 'XXX'),
    (id: 's', name: 'Serier'),
  ];
  final ids = [for (final l in libs) l.id];

  test('finds the adult library by name only', () {
    expect(AdultLibraryService.adultLibraryId(libs), 'x');
    expect(
      AdultLibraryService.adultLibraryId([(id: 'f', name: 'Filmer XXX-mas')]),
      isNull,
    );
    // The installer's plugin names the library "Adult".
    expect(AdultLibraryService.adultLibraryId([(id: 'a', name: 'Adult')]), 'a');
    expect(AdultLibraryService.adultLibraryId([(id: 'b', name: 'Adult Swim')]), isNull);
  });

  test('hiding keeps every other library and turns off "all folders"', () {
    final p = AdultLibraryService.withVisibility(
      {'EnableAllFolders': true, 'EnabledFolders': <String>[], 'IsAdministrator': true},
      ids,
      'x',
      visible: false,
    );
    expect(p['EnableAllFolders'], isFalse);
    expect((p['EnabledFolders'] as List).toSet(), {'a', 's'});
    expect(p['IsAdministrator'], isTrue);
    expect(AdultLibraryService.visibleIn(p, 'x'), isFalse);
  });

  test('showing again goes back to "all folders"', () {
    final p = AdultLibraryService.withVisibility(
      {'EnableAllFolders': false, 'EnabledFolders': ['a', 's']},
      ids,
      'x',
      visible: true,
    );
    expect(p['EnableAllFolders'], isTrue);
    expect(p['EnabledFolders'], isEmpty);
    expect(AdultLibraryService.visibleIn(p, 'x'), isTrue);
  });

  test('a user limited to some libraries stays limited', () {
    final p = AdultLibraryService.withVisibility(
      {'EnableAllFolders': false, 'EnabledFolders': ['a']},
      ids,
      'x',
      visible: true,
    );
    expect(p['EnableAllFolders'], isFalse);
    expect((p['EnabledFolders'] as List).toSet(), {'a', 'x'});
  });
}
