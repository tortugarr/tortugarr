import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/l10n/app_localizations_en.dart';
import 'package:moonfin/ui/screens/detail/item_detail_screen.dart';

AggregatedItem _item(Map<String, dynamic> raw) =>
    AggregatedItem(id: 'i', serverId: 's', rawData: raw);

void main() {
  final l10n = AppLocalizationsEn();

  test('the delete confirmation names what goes', () {
    expect(deleteConfirmMessage(l10n, _item({'Type': 'Movie', 'Name': 'Sita'})),
        'Delete the movie "Sita" and its file?');
    expect(deleteConfirmMessage(l10n, _item({'Type': 'Series', 'Name': 'Pioneer One'})),
        contains('WHOLE series "Pioneer One"'));
    expect(
      deleteConfirmMessage(l10n,
          _item({'Type': 'Season', 'Name': 'Season 1', 'IndexNumber': 1, 'SeriesName': 'Pioneer One'})),
      'Delete season 1 of "Pioneer One" and all its episodes?',
    );
    expect(
      deleteConfirmMessage(l10n, _item({
        'Type': 'Episode',
        'Name': 'Earthfall',
        'IndexNumber': 1,
        'ParentIndexNumber': 1,
        'SeriesName': 'Pioneer One',
      })),
      'Delete episode S01E01 of "Pioneer One"?',
    );
    expect(deleteConfirmMessage(l10n, _item({'Type': 'MusicAlbum', 'Name': 'x'})),
        l10n.deleteItemMessage);
  });
}
