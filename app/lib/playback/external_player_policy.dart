import '../data/models/aggregated_item.dart';

class ExternalPlayerPolicy {
  static const Set<String> _supportedTypes = {
    'Movie',
    'Episode',
    'Video',
    'Series',
    'Season',
    'Recording',
    'TvChannel',
    'Program',
  };

  static bool isEligibleQueue(List<dynamic> items) {
    if (items.isEmpty) return false;
    return items.every(isEligibleItem);
  }

  static bool isEligibleItem(dynamic item) {
    if (item is! AggregatedItem) return false;

    final type = item.type;
    if (type == null || !_supportedTypes.contains(type)) return false;

    final mediaType =
        (item.rawData['MediaType'] as String?)?.trim().toLowerCase();
    if (mediaType == 'audio') return false;

    return true;
  }
}
