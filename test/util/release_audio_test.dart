import 'package:flutter_test/flutter_test.dart';
import 'package:moonfin/util/release_audio.dart';

void main() {
  final cases = <String, List<String>>{
    'Dune.Part.Two.2024.2160p.WEB-DL.DDP5.1.Atmos.H265-FLUX': ['Atmos', 'DD+', '5.1'],
    'Dune.Part.Two.2024.1080p.BluRay.TrueHD.7.1.Atmos-FGT': ['Atmos', 'TrueHD', '7.1'],
    'Dune Part Two 2024 1080p WEB-DL DD5.1 H264': ['DD', '5.1'],
    'Dune.Part.Two.2024.1080p.WEBRip.AAC2.0.x264': ['AAC', 'Stereo'],
    'Movie.2023.2160p.UHD.BluRay.REMUX.DTS-HD.MA.7.1-GROUP': ['DTS-HD MA', '7.1'],
    'Movie 2023 1080p BluRay DTS-X 7.1': ['DTS:X', '7.1'],
    'Show.S01E04.1080p.WEB.h264-EDITH': [],
    'Show.S02E01.2160p.WEB.H265.EAC3.5.1': ['DD+', '5.1'],
    'Movie.2020.1080p.BluRay.x264.AC3-GROUP': ['DD'],
    'Movie.2020.720p.WEB.Opus.5.1': ['Opus', '5.1'],
    'Tron.2.0.Making.Of.1080p.WEB': [],
    'Movie.2019.1080p.WEB.FLAC.2.0': ['FLAC', 'Stereo'],
    'Movie (2021) [1080p] [WEBRip] [5.1] [YTS.MX]': ['5.1'],
    'Hidden.Gems.2021.1080p.WEB.DDP.5.1.Atmos': ['Atmos', 'DD+', '5.1'],
    'Paddington.2014.1080p.ADDiCTiON': [],
  };
  cases.forEach((title, want) {
    test(title, () => expect(releaseAudioBadges(title), want));
  });
}
