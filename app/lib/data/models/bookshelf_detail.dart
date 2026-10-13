import 'aggregated_item.dart';

class BookshelfDetail {
  final String itemId;
  final String? director;
  final List<String> cast;

  final List<String> specPills;

  final String? hdr;

  final bool atmos;

  final double progressFraction;

  const BookshelfDetail({
    required this.itemId,
    this.director,
    this.cast = const [],
    this.specPills = const [],
    this.hdr,
    this.atmos = false,
    this.progressFraction = 0.0,
  });

  /// Maps a full [AggregatedItem] (with People + MediaStreams + UserData) into a
  /// [BookshelfDetail].
  factory BookshelfDetail.fromItem(String itemId, AggregatedItem item) {
    String? director;
    final cast = <String>[];
    for (final person in item.people) {
      final name = (person['Name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final type = (person['Type'] as String?) ?? '';
      final role = (person['Role'] as String?) ?? '';
      if (type == 'Director' && director == null) {
        director = name;
      } else if (type == 'Actor' || role.isNotEmpty) {
        if (cast.length < 5 && !cast.contains(name)) {
          cast.add(name);
        }
      }
    }

    final pills = <String>[];
    final container = _container(item);
    if (container != null) pills.add(container.toUpperCase());
    final resolution = item.videoResolution;
    if (resolution != null) pills.add(resolution);
    final videoCodec = item.videoCodec;
    if (videoCodec != null) pills.add(videoCodec.toUpperCase());
    final audioCodec = item.audioCodec;
    if (audioCodec != null) pills.add(audioCodec.toUpperCase());
    final channels = item.channelLayout;
    if (channels != null) pills.add(channels);

    final hdr = _formatHdr(item.hdrType);
    if (hdr != null) pills.add(hdr);

    final atmos = _detectAtmos(item);
    if (atmos) pills.add('Atmos');

    final percentage = item.playedPercentage;
    final progress = percentage != null
        ? (percentage / 100.0).clamp(0.0, 1.0)
        : 0.0;

    return BookshelfDetail(
      itemId: itemId,
      director: director,
      cast: cast,
      specPills: pills,
      hdr: hdr,
      atmos: atmos,
      progressFraction: progress,
    );
  }

  static String? _container(AggregatedItem item) {
    for (final source in item.mediaSources) {
      final c = (source['Container'] as String?)?.trim();
      if (c != null && c.isNotEmpty) {
        // Containers can be comma separated (e.g. "mov,mp4,m4a"); take first.
        return c.split(',').first.trim();
      }
    }
    return null;
  }

  static String? _formatHdr(String? hdrType) {
    if (hdrType == null) return null;
    final normalized = hdrType.toUpperCase();
    if (normalized.contains('DOVI') || normalized.contains('DOLBY')) {
      return 'Dolby Vision';
    }
    if (normalized.contains('HDR10PLUS') || normalized.contains('HDR10_PLUS')) {
      return 'HDR10+';
    }
    if (normalized.contains('HDR10')) return 'HDR10';
    if (normalized.contains('HLG')) return 'HLG';
    if (normalized.contains('HDR')) return 'HDR';
    return null;
  }

  static bool _detectAtmos(AggregatedItem item) {
    final profile = item.audioProfile?.toLowerCase() ?? '';
    if (profile.contains('atmos') || profile.contains('joc')) return true;
    final codec = item.audioCodec?.toLowerCase() ?? '';
    if (codec.contains('truehd') && profile.contains('atmos')) return true;
    return false;
  }
}
