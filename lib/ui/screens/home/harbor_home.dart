part of 'home_screen.dart';

/// Tortugarr's Harbor home (Row Type > Harbor, TV/desktop), written apart from
/// Moonfin's rows: a sharp full-screen backdrop and the focused title on top,
/// one deck of cards at a time at the bottom as a 3D cover flow, decks
/// switched with Up/Down. Above the first deck sits the Spotlight: a random
/// handful from the library that changes by itself.
class _HarborHome extends StatefulWidget {
  const _HarborHome({required this.viewModel, required this.onItemSelected});

  final HomeViewModel viewModel;
  final void Function(AggregatedItem? item, {bool preserveBackground})
  onItemSelected;

  @override
  State<_HarborHome> createState() => _HarborHomeState();
}

class _HarborDeck {
  const _HarborDeck(
    this.id,
    this.title,
    this.items, {
    this.ranked = false,
    this.library = false,
  });
  final String id;
  final String title;
  final List<AggregatedItem> items;
  final bool ranked;

  /// My Media: the libraries (Movies, TV Shows, Documentaries …).
  final bool library;
}

const _harborCardTypes = {
  'Movie',
  'Series',
  'Episode',
  'Season',
  'BoxSet',
  'Video',
  'MusicVideo',
};

class _HarborHomeState extends State<_HarborHome>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode(debugLabel: 'HarborHome');
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
  );

  /// -1 is the Spotlight.
  int _deck = -1;
  final Map<String, int> _index = {};
  final Set<String> _libraryIds = {};
  List<_HarborDeck> _decks = const [];
  List<AggregatedItem> _spotlight = const [];
  int _spot = 0;
  Timer? _spotTimer;
  AggregatedItem? _reported;

  // Trailer of the focused title, after it has been focused for a moment.
  Timer? _trailerTimer;
  Player? _trailerPlayer;
  VideoController? _trailerController;
  String? _trailerFor;
  bool _trailerShowing = false;
  int _trailerTry = 0;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_rebuildDecks);
    TitleBadges.instance.addListener(_rebuildDecks);
    _rebuildDecks();
    _restartSpotlightTimer();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_rebuildDecks);
    TitleBadges.instance.removeListener(_rebuildDecks);
    _spotTimer?.cancel();
    _trailerTimer?.cancel();
    _trailerPlayer?.dispose();
    _pos.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rebuildDecks() {
    if (!mounted) return;
    final decks = <_HarborDeck>[];
    final l10n = AppLocalizations.of(context);
    for (final row in widget.viewModel.rows) {
      // My Media: the libraries, as wide tiles that open the library.
      if ((row.rowType == HomeRowType.libraryTiles ||
              row.rowType == HomeRowType.libraryTilesSmall) &&
          row.items.isNotEmpty) {
        _libraryIds.addAll(row.items.map((i) => i.id));
        decks.add(
          _HarborDeck(
            row.id,
            localizeHomeRowTitle(
              row: row,
              l10n: l10n,
              mergeContinueWatchingAndNextUp: GetIt.instance<UserPreferences>()
                  .effectiveMergeContinueWatchingNextUp,
            ),
            row.items,
            library: true,
          ),
        );
        continue;
      }
      if (row.rowType == HomeRowType.libraryTiles ||
          row.rowType == HomeRowType.libraryTilesSmall ||
          row.rowType == HomeRowType.liveTv ||
          row.rowType == HomeRowType.liveTvOnNow ||
          row.rowType == HomeRowType.liveTvFavorites ||
          row.isLoading && row.items.isEmpty) {
        continue;
      }
      final items = [
        for (final i in row.items)
          if ((_harborCardTypes.contains(i.type) || i.serverId == 'seerr') &&
              !hideAsMockbuster(i))
            i,
      ];
      if (items.isEmpty) continue;
      decks.add(
        _HarborDeck(
          row.id,
          localizeHomeRowTitle(
            row: row,
            l10n: l10n,
            mergeContinueWatchingAndNextUp: GetIt.instance<UserPreferences>()
                .effectiveMergeContinueWatchingNextUp,
          ),
          items,
          ranked:
              HomeViewModel.isTopListRow(row) &&
              HomeViewModel.isRankedTopList(row.title),
        ),
      );
    }
    final current = _deck >= 0 && _deck < _decks.length
        ? _decks[_deck].id
        : null;
    setState(() {
      _decks = decks;
      if (current != null) {
        final at = decks.indexWhere((d) => d.id == current);
        _deck = at >= 0 ? at : (_deck.clamp(-1, decks.length - 1));
      }
      if (_spotlight.isEmpty) {
        final pool = <String, AggregatedItem>{
          for (final d in decks)
            for (final i in d.items)
              if ((i.type == 'Movie' || i.type == 'Series') &&
                  _backdropUrl(i) != null)
                i.id: i,
        }.values.toList()..shuffle();
        _spotlight = pool.take(10).toList();
      }
    });
    _report();
  }

  void _restartSpotlightTimer() {
    _spotTimer?.cancel();
    _spotTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted || _deck != -1 || _spotlight.length < 2) return;
      setState(() => _spot = (_spot + 1) % _spotlight.length);
      _report();
    });
  }

  AggregatedItem? get _current {
    if (_deck < 0)
      return _spotlight.isEmpty ? null : _spotlight[_spot % _spotlight.length];
    if (_deck >= _decks.length) return null;
    final d = _decks[_deck];
    return d.items[(_index[d.id] ?? 0).clamp(0, d.items.length - 1)];
  }

  void _report() {
    final item = _current;
    if (item == null || identical(item, _reported)) return;
    _reported = item;
    widget.onItemSelected(item, preserveBackground: true);
    _scheduleTrailer(item);
  }

  String get _trailerMode =>
      GetIt.instance<UserPreferences>().get(UserPreferences.tgHarborTrailer);

  /// Stops any trailer and, unless trailers are off, starts the focused
  /// title's after 2.5 s on it.
  void _scheduleTrailer(AggregatedItem item) {
    _trailerTimer?.cancel();
    _trailerTry++;
    if (_trailerShowing || _trailerFor != null) {
      _trailerPlayer?.stop();
      if (mounted) setState(() => _trailerShowing = false);
      _trailerFor = null;
    }
    if (_trailerMode == 'off' || item.serverId == 'seerr') return;
    final attempt = _trailerTry;
    _trailerTimer = Timer(
      const Duration(milliseconds: 2500),
      () => _playTrailer(item, attempt),
    );
  }

  Future<void> _playTrailer(AggregatedItem item, int attempt) async {
    try {
      var trailers =
          (item.rawData['RemoteTrailers'] as List?)
              ?.whereType<Map>()
              .toList() ??
          const [];
      if (trailers.isEmpty) {
        final full = await GetIt.instance<MediaServerClientFactory>()
            .clientForServerOrActive(item.serverId)
            .itemsApi
            .getItem(
              item.type == 'Episode' && item.seriesId != null
                  ? item.seriesId!
                  : item.id,
            );
        trailers =
            (full['RemoteTrailers'] as List?)?.whereType<Map>().toList() ??
            const [];
      }
      if (!mounted || attempt != _trailerTry) return;
      String? stream;
      String? language;
      for (final t in trailers) {
        final url = t['Url'] as String?;
        if (url == null || YouTubeStreamResolver.extractVideoId(url) == null)
          continue;
        final s = await YouTubeStreamResolver.resolveFromUrl(url)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
        if (!mounted || attempt != _trailerTry) return;
        if (s != null) {
          stream = s.url;
          language = s.audioLanguage;
          break;
        }
      }
      if (stream == null) return;
      final player = _trailerPlayer ??= Player(
        configuration: const PlayerConfiguration(libass: false),
      );
      _trailerController ??= VideoController(player);
      await player.setVolume(0);
      await YouTubeStreamResolver.preferAudioLanguage(player, language);
      final media = await YouTubeStreamResolver.previewMedia(
        player,
        stream,
        youTube: true,
        audioLanguage: language,
      );
      if (!mounted || attempt != _trailerTry) return;
      await player.open(media);
      if (!mounted || attempt != _trailerTry) {
        await player.stop();
        return;
      }
      setState(() {
        _trailerFor = item.id;
        _trailerShowing = true;
      });
    } catch (_) {
      // No trailer: the backdrop stays.
    }
  }

  Widget _trailerVideo() => Video(
    controller: _trailerController!,
    controls: NoVideoControls,
    fit: BoxFit.cover,
    pauseUponEnteringBackgroundMode: true,
    fill: Colors.transparent,
  );

  void _moveItem(int delta) {
    if (_deck < 0) {
      if (_spotlight.isEmpty) return;
      setState(() => _spot = (_spot + delta) % _spotlight.length);
      _restartSpotlightTimer();
      _report();
      return;
    }
    final d = _decks[_deck];
    final next = ((_index[d.id] ?? 0) + delta).clamp(0, d.items.length - 1);
    setState(() => _index[d.id] = next);
    _pos.animateTo(
      next.toDouble(),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    _report();
  }

  void _moveDeck(int delta) {
    final next = (_deck + delta).clamp(-1, _decks.length - 1);
    if (next == _deck) return;
    setState(() => _deck = next);
    if (next >= 0) _pos.value = (_index[_decks[next].id] ?? 0).toDouble();
    _report();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final atFirst = _deck >= 0 && (_index[_decks[_deck].id] ?? 0) == 0;
    if (key == LogicalKeyboardKey.arrowRight) {
      _moveItem(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      // From the first card (or the Spotlight), Left goes to the side menu.
      if (atFirst || _deck < 0) {
        final toMenu = NavigationLayout.focusNavbarNotifier.value;
        if (toMenu != null) {
          toMenu();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      _moveItem(-1);
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.handled;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveDeck(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_deck == -1) return KeyEventResult.ignored;
      _moveDeck(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _open(_current);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _open(AggregatedItem? item) {
    if (item == null) return;
    // Leaving Home: no trailer playing behind the details page.
    _trailerTimer?.cancel();
    _trailerTry++;
    _trailerPlayer?.stop();
    if (_trailerShowing) setState(() => _trailerShowing = false);
    if (_libraryIds.contains(item.id)) {
      _ContentRowsState._navigateToLibrary(context, item);
      return;
    }
    if (item.serverId == 'seerr') {
      _ContentRowsState._navigateToSeerrItem(context, item);
      return;
    }
    context.push(
      Destinations.itemOrPhoto(
        item.id,
        serverId: item.serverId,
        type: item.type,
        channelId: item.channelId,
      ),
    );
  }

  // ---------------------------------------------------------------- images

  /// Network, studio and genre tiles: a logo, not a poster.
  static bool _isLogoTile(AggregatedItem item) =>
      item.rawData['FilterType'] != null ||
      const {'Studio', 'Network', 'Genre', 'MusicGenre'}.contains(item.type);

  String? _backdropUrl(AggregatedItem item) {
    // A logo blown up behind the page is no backdrop; libraries have none.
    if (_isLogoTile(item) || _libraryIds.contains(item.id)) return null;
    final path = item.rawData['BackdropPath'] as String?;
    if (item.serverId == 'seerr' || (path != null && path.isNotEmpty)) {
      if (path == null || path.isEmpty) return null;
      return path.startsWith('http')
          ? path
          : 'https://image.tmdb.org/t/p/w1280$path';
    }
    final api = widget.viewModel.imageApiForServer(item.serverId);
    final tags = item.backdropImageTags;
    if (tags.isNotEmpty) {
      return api.getBackdropImageUrl(item.id, maxWidth: 1920, tag: tags.first);
    }
    final parent = item.parentBackdropItemId;
    final parentTags = item.parentBackdropImageTags;
    if (parent != null && parentTags.isNotEmpty) {
      return api.getBackdropImageUrl(
        parent,
        maxWidth: 1920,
        tag: parentTags.first,
      );
    }
    return null;
  }

  String? _logoUrl(AggregatedItem item) {
    if (item.serverId == 'seerr') return null;
    final tags = item.rawData['ImageTags'];
    final tag = tags is Map ? tags['Logo'] as String? : null;
    if (tag != null) {
      return widget.viewModel
          .imageApiForServer(item.serverId)
          .getLogoImageUrl(item.id, maxWidth: 700, tag: tag);
    }
    final parentTag = item.rawData['ParentLogoImageTag'] as String?;
    final parentId = item.rawData['ParentLogoItemId'] as String?;
    if (parentTag != null && parentId != null) {
      return widget.viewModel
          .imageApiForServer(item.serverId)
          .getLogoImageUrl(parentId, maxWidth: 700, tag: parentTag);
    }
    return null;
  }

  String? _posterUrl(AggregatedItem item, double height) =>
      _ContentRowsState._resolveRowImageUrl(
        item,
        widget.viewModel.imageApiForServer(item.serverId),
        height,
        // Logo and library tiles use the wide artwork their rows use.
        _isLogoTile(item) || _libraryIds.contains(item.id)
            ? ImageType.thumb
            : ImageType.poster,
        false,
        MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0),
        isMyMediaRow: _libraryIds.contains(item.id),
      );

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildBackdrop(item),
              if (_trailerShowing &&
                  _trailerController != null &&
                  _trailerMode == 'background')
                Positioned.fill(child: IgnorePointer(child: _trailerVideo())),
              const IgnorePointer(child: _HarborScrims()),
              if (_trailerShowing &&
                  _trailerController != null &&
                  _trailerMode == 'corner')
                Positioned(
                  right: w * 0.04,
                  top: h * 0.07,
                  width: w * 0.36,
                  height: w * 0.36 * 9 / 16,
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: Colors.black),
                        child: _trailerVideo(),
                      ),
                    ),
                  ),
                ),
              if (item != null)
                Positioned(
                  left: w * 0.07,
                  top: h * (_deck < 0 ? 0.16 : 0.08),
                  width: w * 0.5,
                  child: _buildInfo(context, item, h),
                ),
              if (_deck < 0)
                _buildSpotlightFoot(context, w, h)
              else ...[
                Positioned(
                  left: w * 0.07,
                  right: 0,
                  top: h * 0.565,
                  child: _buildDeckTabs(context),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: h * 0.63,
                  bottom: h * 0.02,
                  child: _buildCoverFlow(context, w),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackdrop(AggregatedItem? item) {
    final url = item == null ? null : _backdropUrl(item);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      child: url == null
          ? SizedBox.expand(
              key: const ValueKey('none'),
              child: ColoredBox(color: AppColorScheme.background),
            )
          : SizedBox.expand(
              key: ValueKey(url),
              child: BoundedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                minWidth: 960,
                maxWidth: 1920,
              ),
            ),
    );
  }

  Widget _buildInfo(BuildContext context, AggregatedItem item, double h) {
    final theme = Theme.of(context);
    final logo = _logoUrl(item);
    final year = item.rawData['ProductionYear'];
    final ticks = item.rawData['RunTimeTicks'];
    final minutes = ticks is num ? (ticks / 600000000).round() : null;
    final rating = item.rawData['CommunityRating'];
    final overview = (item.rawData['Overview'] as String?)?.trim() ?? '';
    final kicker = _deck < 0
        ? AppLocalizations.of(context).tgSpotlight
        : _decks[_deck].title;
    final meta = <String>[
      if (year != null) '$year',
      if (minutes != null && minutes > 0)
        minutes >= 60
            ? '${minutes ~/ 60} h ${minutes % 60} min'
            : '$minutes min',
      if (rating is num && rating > 0) '★ ${rating.toStringAsFixed(1)}',
      if (item.type == 'Episode' &&
          item.parentIndexNumber != null &&
          item.indexNumber != null)
        'S${item.parentIndexNumber}:E${item.indexNumber}',
    ];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey(item.id),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kicker.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColorScheme.accent,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (logo != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: h * 0.17, maxWidth: 520),
              child: BoundedNetworkImage(
                imageUrl: logo,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                maxWidth: 800,
              ),
            )
          else
            Text(
              item.type == 'Episode'
                  ? (item.seriesName ?? item.name)
                  : item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColorScheme.onBackground,
                fontWeight: FontWeight.w800,
                height: 1.0,
                shadows: const [Shadow(blurRadius: 12, color: Colors.black54)],
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final m in meta)
                Text(
                  m,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColorScheme.onBackground.withValues(alpha: 0.9),
                  ),
                ),
              _HarborInlineBadges(item: item),
            ],
          ),
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              overview,
              maxLines: _deck < 0 ? 4 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColorScheme.onBackground.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpotlightFoot(BuildContext context, double w, double h) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      left: w * 0.07,
      right: w * 0.07,
      bottom: h * 0.08,
      child: Row(
        children: [
          for (var i = 0; i < _spotlight.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 8),
              width: i == _spot ? 28 : 9,
              height: 9,
              decoration: BoxDecoration(
                color: i == _spot
                    ? AppColorScheme.accent
                    : AppColorScheme.onBackground.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          const Spacer(),
          if (_decks.isNotEmpty)
            Text(
              '▼  ${_decks.first.title}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColorScheme.onBackground.withValues(alpha: 0.85),
              ),
            ),
          if (_decks.isEmpty)
            Text(
              l10n.tgHarborLoading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
        ],
      ),
    );
  }

  Widget _buildDeckTabs(BuildContext context) {
    final theme = Theme.of(context);
    final tabs = <Widget>[];
    for (
      var i = (_deck - 1).clamp(0, _decks.length);
      i < _decks.length && i <= _deck + 3;
      i++
    ) {
      final on = i == _deck;
      tabs.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.only(right: 12),
          padding: EdgeInsets.symmetric(
            horizontal: on ? 18 : 12,
            vertical: on ? 8 : 5,
          ),
          decoration: BoxDecoration(
            color: on
                ? AppColorScheme.accent
                : AppColorScheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            _decks[i].title,
            style:
                (on
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.titleSmall)
                    ?.copyWith(
                      color: on
                          ? AppColorScheme.onAccent
                          : AppColorScheme.onBackground.withValues(alpha: 0.7),
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: tabs),
    );
  }

  Widget _buildCoverFlow(BuildContext context, double w) {
    final deck = _decks[_deck];
    return LayoutBuilder(
      builder: (context, box) {
        // Logo decks (Networks, Studios, Genres) get wide tiles.
        final logos =
            deck.library ||
            (deck.items.isNotEmpty && _isLogoTile(deck.items.first));
        final cardH = box.maxHeight * (logos ? 0.55 : 0.80);
        final cardW = logos ? cardH * 16 / 9 : cardH * 2 / 3;
        final centerX = w * 0.5;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.25),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: AnimatedBuilder(
            key: ValueKey(deck.id),
            animation: _pos,
            builder: (context, _) {
              final pos = _pos.value;
              final first = (pos - 7).floor().clamp(0, deck.items.length - 1);
              final last = (pos + 7).ceil().clamp(0, deck.items.length - 1);
              final order = [for (var i = first; i <= last; i++) i]
                ..sort((a, b) => (b - pos).abs().compareTo((a - pos).abs()));
              final focusedIndex = (_index[deck.id] ?? 0);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final i in order)
                    _coverCard(
                      context,
                      deck,
                      i,
                      i - pos,
                      cardW,
                      cardH,
                      centerX,
                      i == focusedIndex,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _coverCard(
    BuildContext context,
    _HarborDeck deck,
    int i,
    double d,
    double cardW,
    double cardH,
    double centerX,
    bool focused,
  ) {
    final item = deck.items[i];
    final a = d.abs();
    final near = a.clamp(0.0, 1.0);
    final x =
        centerX -
        cardW / 2 +
        d.sign * (near * cardW * 0.92 + (a > 1 ? (a - 1) * cardW * 0.52 : 0));
    final scale = 1.0 - 0.24 * near;
    final opacity = (1.0 - ((a - 4.5).clamp(0.0, 1.5) / 1.5)).clamp(0.0, 1.0);
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..rotateY(-d.clamp(-1.0, 1.0) * 0.55);
    final url = _posterUrl(item, cardH);
    final played = (item.rawData['UserData'] as Map?)?['PlayedPercentage'];
    final borders = ThemeRegistry.active.borders;
    final radius = borders.cardRadius;
    final card = Container(
      width: cardW,
      height: cardH,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: AppColorScheme.surface,
        border: focused
            ? Border.all(color: AppColorScheme.accent, width: 3)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: focused ? 26 : 10,
            offset: const Offset(0, 10),
          ),
          if (focused && ThemeRegistry.active.cardFocusGlow)
            ...borders.focusGlow,
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null && _isLogoTile(item))
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: cardW * 0.12,
                  vertical: cardH * 0.18,
                ),
                child: BoundedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  maxWidth: 600,
                ),
              )
            else if (url != null)
              BoundedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                maxWidth: 600,
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    item.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColorScheme.onSurface),
                  ),
                ),
              ),
            if (deck.library && url != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC000000)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            if (!deck.library) TitleBadgeOverlay(item: item, size: 0.9),
            if (played is num && played > 0 && played < 100)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: played / 100,
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(AppColorScheme.accent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return Positioned(
      left: x,
      top: 0,
      child: Opacity(
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          transform: m,
          child: Transform.scale(
            scale: scale,
            // Centred on the card's middle (not the poster's top), so the
            // side cards line up with the middle of the focused one.
            alignment: Alignment(0, -0.1),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (deck.ranked && a < 0.5)
                  Positioned(
                    right: cardW * 0.93,
                    bottom: -cardH * 0.06,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: cardH * 0.62,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 3
                          ..color = AppColorScheme.accent,
                      ),
                    ),
                  ),
                // Collections lie on two fanned plates, like a small stack.
                if (item.type == 'BoxSet')
                  for (final (angle, alpha) in const [(0.10, 0.5), (0.05, 0.8)])
                    Positioned(
                      left: 0,
                      top: 0,
                      width: cardW,
                      height: cardH,
                      child: Transform.rotate(
                        angle: angle,
                        alignment: Alignment.bottomLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColorScheme.surfaceVariant.withValues(
                              alpha: alpha,
                            ),
                            borderRadius:
                                ThemeRegistry.active.borders.cardRadius,
                            border: Border.all(
                              color: AppColorScheme.onSurface.withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                card,
                if (focused)
                  Positioned(
                    left: -cardW,
                    right: -cardW,
                    top: cardH + 8,
                    child: Column(
                      children: [
                        Text(
                          item.type == 'Episode'
                              ? (item.seriesName ?? item.name)
                              : item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColorScheme.onBackground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if ((item.subtitle ?? '').isNotEmpty)
                          Text(
                            item.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColorScheme.onBackground.withValues(
                                    alpha: 0.75,
                                  ),
                                ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The darkening that keeps text readable over a sharp backdrop.
class _HarborScrims extends StatelessWidget {
  const _HarborScrims();

  @override
  Widget build(BuildContext context) {
    final bg = AppColorScheme.background;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                bg.withValues(alpha: 0.92),
                bg.withValues(alpha: 0.55),
                bg.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.38, 0.72],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                bg.withValues(alpha: 0.97),
                bg.withValues(alpha: 0.75),
                bg.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.42, 0.68],
            ),
          ),
        ),
      ],
    );
  }
}

/// BB / MB and the series network, inline in the info line.
class _HarborInlineBadges extends StatelessWidget {
  const _HarborInlineBadges({required this.item});
  final AggregatedItem item;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TitleBadges.instance,
      builder: (context, _) {
        final info = TitleBadges.instance.infoFor(item);
        if (info == null) return const SizedBox.shrink();
        final chips = <Widget>[];
        if (info.kind != TitleClass.plain) {
          final mb = info.kind == TitleClass.mockbuster;
          chips.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: mb ? const Color(0xFFE0703A) : AppColorScheme.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                mb ? 'MOCKBUSTER' : 'BLOCKBUSTER',
                style: TextStyle(
                  color: mb ? Colors.white : AppColorScheme.onAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          );
        }
        final curated = info.network == null
            ? null
            : curatedLogoUrl(info.network!, width: 500);
        if (curated != null) {
          chips.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110, maxHeight: 20),
                child: Image.network(
                  curated,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          );
        } else if (info.networkLogo != null) {
          chips.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110, maxHeight: 20),
                child: Image.network(
                  info.networkLogo!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => Text(
                    info.network ?? '',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in chips)
              Padding(padding: const EdgeInsets.only(right: 8), child: c),
          ],
        );
      },
    );
  }
}
