import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/models/aggregated_item.dart';
import 'package:moonfin/data/services/tortugarr/title_badges.dart';

void main() {
  test('the TMDB keyword or a mockbuster studio makes MB, even with a big vote count', () {
    expect(classifyMovie({'keywords': [{'name': 'Mockbuster'}], 'voteCount': 9000}), TitleClass.mockbuster);
    expect(classifyMovie({'productionCompanies': [{'name': 'The Asylum'}]}), TitleClass.mockbuster);
    expect(classifyMovie({'productionCompanies': [{'name': 'Asylum Features'}]}), TitleClass.plain);
  });

  test('budget, revenue or votes make BB', () {
    expect(classifyMovie({'budget': 60000000}), TitleClass.blockbuster);
    expect(classifyMovie({'revenue': 150000000}), TitleClass.blockbuster);
    expect(classifyMovie({'voteCount': 5000}), TitleClass.blockbuster);
    expect(classifyMovie({'budget': 2000000, 'voteCount': 300}), TitleClass.plain);
  });

  test('a series gets its first network and a white logo', () {
    final i = seriesInfo({'networks': [{'name': 'HBO', 'logoPath': '/hbo.png'}, {'name': 'Max'}]});
    expect(i.network, 'HBO');
    expect(i.networkLogo, 'https://image.tmdb.org/t/p/w185/hbo.png');
    expect(seriesInfo({}).networkLogo, isNull);
  });

  test('facts survive the device cache round trip', () {
    const i = TitleBadgeInfo(kind: TitleClass.mockbuster, network: 'X', networkLogo: 'u');
    final back = TitleBadgeInfo.fromJson(i.toJson());
    expect(back.kind, TitleClass.mockbuster);
    expect(back.network, 'X');
    expect(back.networkLogo, 'u');
  });

  test('a film gets its first studio with a logo, plus its BB/MB class', () {
    final i = movieInfo({
      'budget': 90000000,
      'productionCompanies': [
        {'name': 'Syncopy', 'logoPath': '/sy.png'},
        {'name': 'Warner Bros. Pictures', 'logoPath': '/wb.png'},
      ],
    });
    expect(i.kind, TitleClass.blockbuster);
    expect(i.network, 'Warner Bros. Pictures');
    expect(i.networkLogo, endsWith('/wb.png'));
    expect(movieInfo({}).networkLogo, isNull);
  });

  test('episodes and seasons are looked up through their series, films and series by TMDB id', () {
    AggregatedItem it(Map<String, dynamic> raw, {String server = 's1'}) => AggregatedItem(id: 'x', serverId: server, rawData: raw);
    expect(TitleBadges.keyFor(it({'Type': 'Episode', 'SeriesId': 'abc'}, server: 'http://192.168.1.15:8096')), 'jfseries:abc@http://192.168.1.15:8096');
    expect(TitleBadges.keyFor(it({'Type': 'Season', 'SeriesId': 'abc'})), 'jfseries:abc@s1');
    expect(TitleBadges.keyFor(it({'Type': 'Episode'})), isNull);
    expect(TitleBadges.keyFor(it({'Type': 'Series', 'ProviderIds': {'Tmdb': '42'}})), 'tv:42');
    expect(TitleBadges.keyFor(it({'Type': 'Movie', 'ProviderIds': {'Tmdb': '7'}})), 'movie:7');
  });
}
