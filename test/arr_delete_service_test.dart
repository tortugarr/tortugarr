import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/data/services/download/arr_delete_service.dart';

void main() {
  test('only deletes the exact file Radarr/Sonarr track', () {
    const jf = '/media/WindowsE/-=MOVIES=-/Siping (2026)/Siping.2026.1080p.WEB-DL.mkv';
    expect(ArrDeleteService.sameFile(jf, '/media/WindowsE/-=MOVIES=-/Siping (2026)/Siping.2026.1080p.WEB-DL.mkv'), isTrue);
    expect(ArrDeleteService.sameFile(jf, '/movies/Siping (2026)/siping.2026.1080p.web-dl.mkv'), isTrue);
    expect(ArrDeleteService.sameFile(jf, '/media/WindowsH/-= MOVIES =-/Siping (2026)/Siping.2026.2160p.mkv'), isFalse);
    expect(ArrDeleteService.sameFile(jf, null), isFalse);
    expect(ArrDeleteService.sameFile(null, '/x/y.mkv'), isTrue);
  });
}
