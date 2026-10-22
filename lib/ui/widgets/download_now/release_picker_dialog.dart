import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../data/services/download/prowlarr_search_client.dart';
import '../../../l10n/app_localizations.dart';
import '../focus/focusable_wrapper.dart';
import '../seerr/seerr_tv_controls.dart';
import '../track_selector_dialog.dart' show showStyledPlayerDialog;
import 'package:moonfin/util/app_l10n.dart';

/// What the user picked (or null if they cancelled).
class ReleaseChoice {
  final ProwlarrRelease release;
  const ReleaseChoice(this.release);
}

/// The Prowlarr query for a picker search. The year only helps movies (it
/// separates remakes). For TV it is the series' start year, which episode
/// releases never contain: "American Horror Story S13E04 2011" finds nothing.
@visibleForTesting
String releaseSearchQuery(String query, {required String mediaType, int? year}) {
  if (year == null || mediaType != 'movie') return query;
  return '$query $year';
}

/// Build a [showReleasePickerDialog] call from a search query. Returns the
/// picked release or null.
Future<ReleaseChoice?> showReleasePickerDialog(
  BuildContext context, {
  required String title,
  required String mediaType,
  required String query,
  int? year,
  String? initialTier,
  DateTime? notPublishedBefore,
}) async {
  final client = ProwlarrSearchClient();
  final List<ProwlarrRelease> found;
  if (mediaType == 'xxx') {
    found = await client.searchKeywords(query: query, mediaType: mediaType);
  } else {
    final withYear = releaseSearchQuery(query, mediaType: mediaType, year: year);
    var hits = await client.search(query: withYear, mediaType: mediaType);
    // Release names often leave the year out; try once more without it.
    if (hits.isEmpty && withYear != query) {
      hits = await client.search(query: query, mediaType: mediaType);
    }
    found = hits;
  }
  // Published before the movie was out digitally = renamed CAM or a
  // mockbuster with the same title. Two days' slack for early web leaks.
  final cutoff = notPublishedBefore?.subtract(const Duration(days: 2));
  final releases = cutoff == null
      ? found
      : found
          .where((r) => r.publishDate == null || !r.publishDate!.isBefore(cutoff))
          .toList();
  if (releases.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(found.isEmpty
            ? appL10n().tgNoReleasesOnProwlarr
            : appL10n().tgOnlyEarlyFiles(found.length)),
      ));
    }
    return null;
  }
  if (!context.mounted) return null;
  return showReleaseListDialog(
    context,
    title: title,
    releases: releases,
    initialTier: initialTier,
    // Adult releases are browsed like a torrent site: everything at
    // once, most seeded first, instead of the best movie file.
    browse: mediaType == 'xxx',
  );
}

/// The picker itself, for releases that were found elsewhere (the public
/// build gets them from the server's Tortugarr plugin).
Future<ReleaseChoice?> showReleaseListDialog(
  BuildContext context, {
  required String title,
  required List<ProwlarrRelease> releases,
  String? initialTier,
  bool browse = false,
  String? note,
}) {
  return showStyledPlayerDialog<ReleaseChoice>(
    context,
    title: title,
    subtitle: note == null
        ? appL10n().tgChooseFileResults(releases.length)
        : appL10n().tgChooseFileResultsNote(releases.length, note),
    builder: (_) => _ReleasePickerBody(
      releases: releases,
      initialTier: initialTier,
      browse: browse,
    ),
  );
}

/// Asked before searching for a movie that is not out on digital/disc yet.
/// Returns true only when the user explicitly wants to see files anyway.
Future<bool> confirmNotReleasedYet(
  BuildContext context, {
  required String title,
  DateTime? homeRelease,
}) async {
  final when = homeRelease == null
      ? appL10n().tgNoDigitalDate
      : appL10n().tgDigitalOn(appLongDate(homeRelease));
  final result = await showStyledPlayerDialog<bool>(
    context,
    title: appL10n().tgNotOutDigitally,
    subtitle: appL10n().tgTitleWhen(title, when),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            appL10n().tgNotOutExplain,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgCancel,
                  primary: true,
                  primaryColor: AppColorScheme.accent,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SeerrDialogButton(
                  label: appL10n().tgShowFilesAnyway,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class _ReleasePickerBody extends StatefulWidget {
  final List<ProwlarrRelease> releases;
  final String? initialTier;
  final bool browse;
  const _ReleasePickerBody({
    required this.releases,
    this.initialTier,
    this.browse = false,
  });

  @override
  State<_ReleasePickerBody> createState() => _ReleasePickerBodyState();
}

class _ReleasePickerBodyState extends State<_ReleasePickerBody> {
  /// Selected tier filter — "2160p" / "1080p" / "720p" / "all".
  String _tier = '2160p';

  /// Per-tier sort order: tier label -> ordered list of releases.
  late final Map<String, List<ProwlarrRelease>> _byTier = _bucket(widget.releases);

  @override
  void initState() {
    super.initState();
    // Honor the caller's preferred tier when it has results, otherwise
    // default to the best tier that has any results.
    final preferred = widget.initialTier;
    if (widget.browse) {
      _tier = 'all';
    } else if (preferred != null &&
        preferred != 'all' &&
        (_byTier[preferred] ?? const []).isNotEmpty) {
      _tier = preferred;
    } else if ((_byTier['2160p'] ?? const []).isNotEmpty) {
      _tier = '2160p';
    } else if ((_byTier['1080p'] ?? const []).isNotEmpty) {
      _tier = '1080p';
    } else if ((_byTier['720p'] ?? const []).isNotEmpty) {
      _tier = '720p';
    } else {
      _tier = 'all';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final availableTiers = <String>[
      if ((_byTier['2160p'] ?? const []).isNotEmpty) '2160p',
      if ((_byTier['1080p'] ?? const []).isNotEmpty) '1080p',
      if ((_byTier['720p'] ?? const []).isNotEmpty) '720p',
      if ((_byTier['other'] ?? const []).isNotEmpty) 'other',
      'all',
    ];
    final visible = _tier == 'all'
        ? widget.releases
        : (_byTier[_tier] ?? const <ProwlarrRelease>[]);
    // Stable sort inside the tier: by size desc so the biggest 2160p
    // (Remux) is the default pick, but the user can scroll to smaller
    // encodes if they want to save space.
    // Browse mode keeps the order it was given (keyword search ranks it).
    final sorted = widget.browse
        ? visible
        : ([...visible]
      ..sort((a, b) {
        final bySize = b.size.compareTo(a.size);
        if (bySize != 0) return bySize;
        return b.seeders.compareTo(a.seeders);
      }));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: Colors.white12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTiers.map((t) {
              final count = t == 'all'
                  ? widget.releases.length
                  : (_byTier[t] ?? const []).length;
              return SeerrChoiceChip(
                label: '${switch (t) {
                  'all' => appL10n().tgTierAll,
                  'other' => appL10n().tgTierOther,
                  _ => t,
                }} · $count',
                selected: t == _tier,
                onSelected: (_) => setState(() => _tier = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          for (final r in sorted) _ReleaseRow(release: r),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SeerrDialogButton(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Map<String, List<ProwlarrRelease>> _bucket(
    List<ProwlarrRelease> releases,
  ) {
    final out = <String, List<ProwlarrRelease>>{
      '2160p': [],
      '1080p': [],
      '720p': [],
      'other': [],
    };
    for (final r in releases) {
      out[r.tierLabel]?.add(r);
    }
    return out;
  }
}

String _age(DateTime published) {
  final days = DateTime.now().toUtc().difference(published.toUtc()).inDays;
  if (days <= 0) return appL10n().tgToday;
  if (days == 1) return appL10n().tgYesterday;
  if (days < 60) return appL10n().tgDaysAgo(days);
  final months = (days / 30.4).round();
  if (months < 24) return appL10n().tgMonthsAgo(months);
  return appL10n().tgYearsAgo(months ~/ 12);
}

class _ReleaseRow extends StatelessWidget {
  final ProwlarrRelease release;
  const _ReleaseRow({required this.release});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FocusableWrapper(
        onSelect: () =>
            Navigator.of(context).pop(ReleaseChoice(release)),
        borderRadius: 10,
        disableScale: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: AppRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      release.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (release.lowQuality) appL10n().tgSdLowQuality,
                        release.indexer,
                        appL10n().tgSeedersCount(release.seeders),
                        if (release.publishDate != null)
                          _age(release.publishDate!),
                      ].join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColorScheme.accent.withValues(alpha: 0.85),
                  borderRadius: AppRadius.circular(8),
                ),
                child: Text(
                  release.sizeLabel,
                  style: TextStyle(
                    color: AppColorScheme.onAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
