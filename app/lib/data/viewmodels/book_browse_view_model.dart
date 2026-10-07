import 'package:flutter/foundation.dart';
import 'package:server_core/server_core.dart';

import '../../l10n/current_app_localizations.dart';
import '../models/aggregated_item.dart';
import '../models/home_row.dart';
import '../services/row_data_source.dart';

/// Which formats the library tab is currently showing. Only meaningful for
/// mixed libraries; single-format libraries always behave like [all].
enum BookScope { all, books, audiobooks }

class BookBrowseViewModel extends ChangeNotifier {
  final RowDataSource _dataSource;
  final MediaServerClient _client;
  final String libraryId;

  static const _seriesSourceLimit = 200;

  List<HomeRow> _rows = [];
  List<HomeRow> get rows => _rows;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String _libraryName = '';
  String get libraryName => _libraryName;

  String? _collectionType;
  String? get collectionType => _collectionType;

  bool get isAudiobookLibrary => _collectionType == 'audiobooks';

  BookScope _scope = BookScope.all;
  BookScope get scope => _scope;

  int _bookCount = 0;
  int get bookCount => _bookCount;
  int _audiobookCount = 0;
  int get audiobookCount => _audiobookCount;

  /// True when the library holds both regular books and audiobooks, which
  /// enables the scope filter and the per-format rows.
  bool get isMixedLibrary =>
      !isAudiobookLibrary && _bookCount > 0 && _audiobookCount > 0;

  AggregatedItem? _featured;
  AggregatedItem? get featuredItem => _featured;

  int _titleCount = 0;
  int get titleCount => _titleCount;
  int _genreCount = 0;
  int get genreCount => _genreCount;
  int _seriesCount = 0;
  int get seriesCount => _seriesCount;
  int _authorCount = 0;
  int get authorCount => _authorCount;

  // Source rows kept unfiltered so scope switches recompose without refetch.
  HomeRow? _resumeRow;
  HomeRow? _latestBooksRow;
  HomeRow? _latestAudiobooksRow;
  HomeRow? _lastPlayedRow;
  HomeRow? _authorsRow;
  HomeRow? _genresRow;
  HomeRow? _collectionsRow;
  HomeRow? _favoritesRow;
  HomeRow? _allRow;
  List<AggregatedItem> _seriesSource = const [];

  String get _serverId => _client.baseUrl;
  ImageApi get imageApi => _dataSource.imageApi;

  BookBrowseViewModel({
    required this.libraryId,
    required RowDataSource dataSource,
    required MediaServerClient client,
    String? collectionType,
  }) : _dataSource = dataSource,
       _client = client,
       _collectionType = collectionType;

  String get _latestBooksRowId => 'latestBooks_$libraryId';
  String get _latestAudiobooksRowId => 'latestAudiobooks_$libraryId';
  String get _lastPlayedRowId => 'lastPlayed_$libraryId';
  String get _favoritesRowId => 'favorites_$libraryId';
  String get _allRowId => 'allTitles_$libraryId';

  List<String> get _audiobookTypes =>
      isAudiobookLibrary ? const ['AudioBook', 'Audio'] : const ['AudioBook'];

  /// Types for whole-library queries. Books libraries include AudioBook so
  /// audiobooks shelved in a books library are no longer invisible.
  List<String> get combinedTypes =>
      isAudiobookLibrary ? const ['AudioBook', 'Audio'] : const ['Book', 'AudioBook'];

  /// Types matching the active scope, for See-all navigation and genre routes.
  List<String> get scopedTypes {
    if (isAudiobookLibrary) return _audiobookTypes;
    return switch (_scope) {
      BookScope.books => const ['Book'],
      BookScope.audiobooks => _audiobookTypes,
      BookScope.all => combinedTypes,
    };
  }

  /// Whether [item] is an audiobook (vs a regular book). Explicit server
  /// types win; the heuristic only breaks ties for bare audio items.
  bool isAudiobookItem(AggregatedItem item) {
    final type = item.type;
    if (type == 'AudioBook' || type == 'Audio') return true;
    if (type == 'Book') return false;
    return item.isAudiobook;
  }

  /// Item types the See-all grid should show for [row]. Lives here so the
  /// mapping sits next to where the row ids are minted.
  List<String> seeAllTypesFor(HomeRow row) {
    if (row.id == _latestBooksRowId) return const ['Book'];
    if (row.id == _latestAudiobooksRowId || row.id == _lastPlayedRowId) {
      return _audiobookTypes;
    }
    return scopedTypes;
  }

  /// Whether [row] can hold both formats at once, which is when cards show
  /// the format badge.
  bool rowCanMixFormats(HomeRow row) {
    if (!isMixedLibrary || _scope != BookScope.all) return false;
    return row.rowType == HomeRowType.resume ||
        row.id == _favoritesRowId ||
        row.id == _allRowId;
  }

  bool _matchesScope(AggregatedItem item) => switch (_scope) {
    BookScope.all => true,
    BookScope.books => !isAudiobookItem(item),
    BookScope.audiobooks => isAudiobookItem(item),
  };

  /// Time left in an audiobook (or book with server progress); null without
  /// runtime or progress.
  Duration? remainingFor(AggregatedItem item) {
    final runtime = item.runtime;
    if (runtime == null) return null;
    final pct = item.playedPercentage;
    if (pct == null || pct <= 0) return runtime;
    if (pct >= 100) return Duration.zero;
    return Duration(
      microseconds: (runtime.inMicroseconds * (1.0 - pct / 100.0)).round(),
    );
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    final l10n = currentAppLocalizations();

    try {
      final itemData = await _client.itemsApi.getItem(libraryId);
      _libraryName = itemData['Name'] as String? ?? l10n.books;
      final fetchedType = (itemData['CollectionType'] as String?)?.toLowerCase();
      if (fetchedType != null && fetchedType.isNotEmpty) {
        _collectionType = fetchedType;
      }
    } catch (_) {}

    try {
      final resumeTitle = isAudiobookLibrary
          ? l10n.continueListening
          : l10n.continueReading;
      final resumeF = _dataSource.loadBookResume(
        libraryId,
        _serverId,
        includeItemTypes: combinedTypes,
        title: resumeTitle,
      );
      final latestBooksF = isAudiobookLibrary
          ? null
          : _dataSource.loadLibraryItemsByType(
              libraryId,
              _serverId,
              title: l10n.latestBooks,
              includeItemTypes: const ['Book'],
              sortBy: 'DateCreated',
              sortOrder: 'Descending',
            );
      final latestAudiobooksF = _dataSource.loadLibraryItemsByType(
        libraryId,
        _serverId,
        title: l10n.latestAudiobooks,
        includeItemTypes: _audiobookTypes,
        sortBy: 'DateCreated',
        sortOrder: 'Descending',
      );
      final lastPlayedF = isAudiobookLibrary
          ? _dataSource.loadLibraryLastPlayed(
              libraryId,
              _serverId,
              includeItemTypes: _audiobookTypes,
            )
          : null;
      final authorsF = _dataSource.loadBookAuthors(libraryId, _serverId);
      final favoritesF = _dataSource.loadLibraryFavorites(
        libraryId,
        _serverId,
        includeItemTypes: combinedTypes,
      );
      final genresF = _dataSource.loadGenres(
        _serverId,
        includeItemTypes: combinedTypes,
        parentId: libraryId,
      );
      final collectionsF = _loadBookCollections();
      final allF = _dataSource.loadLibraryItemsByType(
        libraryId,
        _serverId,
        title: isAudiobookLibrary ? l10n.audiobooks : l10n.books,
        includeItemTypes: combinedTypes,
        sortBy: 'SortName',
      );
      final seriesSourceF = _loadSeriesSource();
      final bookCountF = isAudiobookLibrary
          ? Future.value(0)
          : _countOf(const ['Book']);
      final audiobookCountF = _countOf(_audiobookTypes);

      await Future.wait([
        resumeF,
        ?latestBooksF,
        latestAudiobooksF,
        ?lastPlayedF,
        authorsF,
        favoritesF,
        genresF,
        collectionsF,
        allF,
        seriesSourceF,
        bookCountF,
        audiobookCountF,
      ]);

      _resumeRow = await resumeF;
      _latestBooksRow = latestBooksF == null
          ? null
          : (await latestBooksF).copyWith(id: _latestBooksRowId);
      _latestAudiobooksRow = (await latestAudiobooksF).copyWith(
        id: _latestAudiobooksRowId,
      );
      _lastPlayedRow = lastPlayedF == null ? null : await lastPlayedF;
      _authorsRow = await authorsF;
      _favoritesRow = await favoritesF;
      _genresRow = await genresF;
      _collectionsRow = await collectionsF;
      _allRow = (await allF).copyWith(id: _allRowId);
      _seriesSource = await seriesSourceF;
      _bookCount = await bookCountF;
      _audiobookCount = await audiobookCountF;

      final resume = _resumeRow!;
      _featured = resume.items.isNotEmpty
          ? resume.items.first
          : (_latestBooksRow?.items.firstOrNull ??
                _latestAudiobooksRow?.items.firstOrNull);
      final all = _allRow!;
      _titleCount = all.totalCount > 0 ? all.totalCount : all.items.length;
      _genreCount = _genresRow?.items.length ?? 0;
      _authorCount = (_authorsRow?.totalCount ?? 0) > 0
          ? _authorsRow!.totalCount
          : (_authorsRow?.items.length ?? 0);
      _composeRows();
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    _rows = [];
    notifyListeners();
    await load();
  }

  void setScope(BookScope value) {
    if (_scope == value) return;
    _scope = value;
    _composeRows();
    notifyListeners();
  }

  void _composeRows() {
    final seriesRow = _buildSeriesRow();
    _seriesCount = seriesRow?.items.length ?? 0;
    final showBooks = _scope != BookScope.audiobooks;
    final showAudiobooks = _scope != BookScope.books;

    final composed = <HomeRow?>[
      _scopedRow(_resumeRow),
      if (showBooks && !isAudiobookLibrary) _latestBooksRow,
      if (showAudiobooks) _latestAudiobooksRow,
      if (showAudiobooks) _lastPlayedRow,
      seriesRow,
      _authorsRow,
      _genresRow,
      _collectionsRow,
      _scopedRow(_favoritesRow),
      _scopedRow(_allRow),
    ];
    _rows = composed
        .whereType<HomeRow>()
        .where((r) => r.items.isNotEmpty)
        .toList();
  }

  HomeRow? _scopedRow(HomeRow? row) {
    if (row == null || _scope == BookScope.all) return row;
    return row.copyWith(items: row.items.where(_matchesScope).toList());
  }

  Future<int> _countOf(List<String> types) async {
    try {
      final resp = await _client.itemsApi.getItems(
        parentId: libraryId,
        includeItemTypes: types,
        recursive: true,
        limit: 1,
        enableTotalRecordCount: true,
      );
      return resp['TotalRecordCount'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<AggregatedItem>> _loadSeriesSource() async {
    try {
      final resp = await _client.itemsApi.getItems(
        parentId: libraryId,
        includeItemTypes: combinedTypes,
        recursive: true,
        limit: _seriesSourceLimit,
        sortBy: 'SortName',
        sortOrder: 'Ascending',
        fields: 'SeriesName,ImageTags,UserData,RunTimeTicks,DateCreated',
        enableImageTypes: 'Primary',
        imageTypeLimit: 1,
      );
      final items = (resp['Items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (raw) => AggregatedItem(
              id: raw['Id']?.toString() ?? '',
              serverId: _serverId,
              rawData: raw.cast<String, dynamic>(),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();
      return items;
    } catch (_) {
      return const [];
    }
  }

  /// Groups the sampled library items on SeriesName into one synthetic entry
  /// per series (2+ members). Synthetic ids use the `bookSeries:` prefix and
  /// carry the series name so taps can run a search.
  HomeRow? _buildSeriesRow() {
    if (_seriesSource.isEmpty) return null;
    final l10n = currentAppLocalizations();
    final groups = <String, List<AggregatedItem>>{};
    for (final item in _seriesSource) {
      if (!_matchesScope(item)) continue;
      final series = item.seriesName?.trim();
      if (series == null || series.isEmpty) continue;
      groups.putIfAbsent(series, () => []).add(item);
    }
    groups.removeWhere((_, members) => members.length < 2);
    if (groups.isEmpty) return null;

    final entries = groups.entries.map((entry) {
      final members = entry.value;
      final cover = members.firstWhere(
        (m) => m.primaryImageTag != null,
        orElse: () => members.first,
      );
      return AggregatedItem(
        id: 'bookSeries:${entry.key}',
        serverId: members.first.serverId,
        rawData: {
          'Name': entry.key,
          'Type': 'BookSeries',
          'ChildCount': members.length,
          if (cover.primaryImageTag != null) ...{
            'PrimaryImageItemId': cover.id,
            'PrimaryImageTag': cover.primaryImageTag,
          },
        },
      );
    }).toList();
    entries.sort((a, b) => a.name.compareTo(b.name));

    return HomeRow(
      id: 'bookSeries_$libraryId',
      title: l10n.series,
      items: entries,
      rowType: HomeRowType.latestMedia,
      totalCount: entries.length,
    );
  }

  Future<HomeRow> _loadBookCollections() async {
    final raw = await _dataSource.loadLibraryCollections(libraryId, _serverId);
    if (raw.items.isEmpty) return raw;
    final types = combinedTypes;
    final containsBooks = await Future.wait(
      raw.items.map((box) async {
        try {
          final resp = await _client.itemsApi.getItems(
            parentId: box.id,
            includeItemTypes: types,
            recursive: true,
            limit: 8,
          );
          final items = (resp['Items'] as List?) ?? const [];
          return items.any((it) {
            final type = (it is Map ? it['Type'] : null) as String?;
            return type != null && types.contains(type);
          });
        } catch (_) {
          return false;
        }
      }),
    );
    final kept = <AggregatedItem>[
      for (var i = 0; i < raw.items.length; i++)
        if (containsBooks[i]) raw.items[i],
    ];
    return raw.copyWith(items: kept);
  }

  String bookSubtitle(AggregatedItem item) {
    final l10n = currentAppLocalizations();
    switch (item.type) {
      case 'BoxSet':
        final count = item.childCount;
        return count != null && count > 0 ? '$count items' : '';
      case 'BookSeries':
        final count = item.childCount ?? 0;
        return count > 0 ? l10n.bookSeriesItemCount(count) : '';
      case 'MusicArtist':
        return '';
      default:
        final author =
            (item.rawData['AlbumArtist'] as String?) ??
            item.seriesName ??
            (item.rawData['Artists'] as List?)?.cast<String>().firstOrNull ??
            '';
        return author;
    }
  }

  String? bookImageUrl(AggregatedItem item) {
    if (item.primaryImageTag != null) {
      return imageApi.getPrimaryImageUrl(
        item.id,
        maxHeight: 400,
        tag: item.primaryImageTag,
      );
    }
    final fieldTag = item.primaryImageTagField;
    final fieldItemId = item.primaryImageItemId;
    if (fieldTag != null && fieldItemId != null) {
      return imageApi.getPrimaryImageUrl(
        fieldItemId,
        maxHeight: 400,
        tag: fieldTag,
      );
    }
    final albumTag = item.albumPrimaryImageTag;
    final albumId = item.albumId;
    if (albumTag != null && albumId != null) {
      return imageApi.getPrimaryImageUrl(
        albumId,
        maxHeight: 400,
        tag: albumTag,
      );
    }
    final parentTag =
        (item.rawData['SeriesPrimaryImageTag'] as String?) ??
        (item.rawData['ParentPrimaryImageTag'] as String?);
    final parentId =
        item.rawData['SeriesId']?.toString() ??
        item.rawData['ParentPrimaryImageItemId']?.toString() ??
        item.parentId;
    if (parentTag != null && parentId != null) {
      return imageApi.getPrimaryImageUrl(parentId, maxHeight: 400, tag: parentTag);
    }
    return null;
  }
}
