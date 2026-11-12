import 'package:flutter_test/flutter_test.dart';
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
    expect(i.networkLogo, 'https://image.tmdb.org/t/p/w154_filter(duotone,ffffff,bababa)/hbo.png');
    expect(seriesInfo({}).networkLogo, isNull);
  });

  test('facts survive the device cache round trip', () {
    const i = TitleBadgeInfo(kind: TitleClass.mockbuster, network: 'X', networkLogo: 'u');
    final back = TitleBadgeInfo.fromJson(i.toJson());
    expect(back.kind, TitleClass.mockbuster);
    expect(back.network, 'X');
    expect(back.networkLogo, 'u');
  });
}
