/// Sound badges for a release, read from its name before anything is
/// downloaded: `Dune.2024.2160p.WEB-DL.DDP5.1.Atmos` → `[Atmos, DD+, 5.1]`.
///
/// 2026-11-07: the picker showed no audio format, so which of ten releases
/// had Atmos was only known after the download. A name without audio words
/// gets no badge (unknown, not "no surround"). Files already in the library
/// show their real format on the details page (audio_labels.dart).
List<String> releaseAudioBadges(String title) {
  // Dots, underscores and brackets as spaces, so word bounds work on scene names.
  final t = ' ${title.toLowerCase().replaceAll(RegExp(r'[._\[\]()]'), ' ')} ';
  final badges = <String>[];

  if (RegExp(r'\batmos\b').hasMatch(t)) badges.add('Atmos');

  final codecs = <(RegExp, String)>[
    (RegExp(r'\btrue ?-?hd'), 'TrueHD'),
    (RegExp(r'\bdts ?[-:]? ?x\b'), 'DTS:X'),
    (RegExp(r'\bdts ?-? ?hd ?-? ?ma'), 'DTS-HD MA'),
    (RegExp(r'\bdts ?-? ?hd'), 'DTS-HD'),
    (RegExp(r'\bdts'), 'DTS'),
    (RegExp(r'\b(ddp|dd\+|e-?ac-?3|dd ?plus)'), 'DD+'),
    (RegExp(r'\b(dd(?= ?\d \d)|ac-?3\b|dolby digital\b)'), 'DD'),
    (RegExp(r'\bflac'), 'FLAC'),
    (RegExp(r'\bopus\b'), 'Opus'),
    (RegExp(r'\baac'), 'AAC'),
  ];
  int? codecAt;
  for (final (re, label) in codecs) {
    final m = re.firstMatch(t);
    if (m != null) {
      badges.add(label);
      codecAt = m.start;
      break;
    }
  }

  // Channels: right after the codec (DDP5.1, AAC2.0, TrueHD.7.1), or a lone
  // 7.1 / 5.1 anywhere. A lone 2.0 is left out: "Tron 2.0" is a title.
  final channel = RegExp(r'(?<![\d])([1-7]) ([01])(?: ?ch)?(?![\d])');
  String? layout;
  for (final m in channel.allMatches(t)) {
    final near = codecAt != null && m.start >= codecAt && m.start - codecAt <= 16;
    final c = '${m.group(1)}.${m.group(2)}';
    if (near || c == '7.1' || c == '5.1') {
      layout = c;
      break;
    }
  }
  if (layout != null) {
    badges.add(switch (layout) {
      '2.0' => 'Stereo',
      '1.0' => 'Mono',
      _ => layout,
    });
  }
  return badges;
}
