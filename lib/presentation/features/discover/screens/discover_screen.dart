/// Entry point of the discovery flow: one large search box.
///
/// Deliberately does no network work. Submitting writes the trimmed query to
/// [searchQueryProvider] and navigates to `/discover/results`, where
/// [searchResultsProvider] does the fetch and owns the loading state — so
/// there is no spinner to show here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../application/providers/discovery_provider.dart';
import '../../../../domain/models/media_discovery.dart';
import '../discover_routes.dart';

/// Outer padding. Wide enough to clear TV overscan on a 1080p panel.
const double _screenPadding = 48;

/// Input text size. The brief asks for both "32pt" and "18-20pt" in different
/// places; 24 is the compromise — readable from a sofa without the field
/// swallowing the screen.
const double _fieldFontSize = 24;

/// Keeps the field from stretching to 1920px on a TV.
const double _maxContentWidth = 900;

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  late final TextEditingController _controller;
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'discoverSearchField');
  final FocusNode _buttonFocus = FocusNode(debugLabel: 'discoverSearchButton');

  /// Set when the user submits an empty box, cleared on the next good submit.
  bool _showEmptyQueryHint = false;

  @override
  void initState() {
    super.initState();
    // Seeded from the provider so backing out of the results screen and
    // returning shows what was searched for instead of an empty box.
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    _controller.dispose();
    _fieldFocus.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _showEmptyQueryHint = true);
      _fieldFocus.requestFocus();
      return;
    }
    if (_showEmptyQueryHint) {
      setState(() => _showEmptyQueryHint = false);
    }

    // A new search invalidates whatever was picked against the previous one.
    // Without this, backing out mid-flow and searching again would carry a
    // stale title (and its ticked releases) into the next request.
    ref.read(selectedMediaProvider.notifier).state = null;
    ref.read(selectedFilesProvider.notifier).state = const <FileOption>[];
    ref.read(searchQueryProvider.notifier).state = query;

    context.go(DiscoverRoutes.results);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(_screenPadding),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Search for something to download',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  key: const Key('discoverSearchField'),
                  controller: _controller,
                  focusNode: _fieldFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  style: const TextStyle(fontSize: _fieldFontSize),
                  decoration: InputDecoration(
                    labelText: 'Movie or TV title',
                    hintText: 'Dune, Severance, ...',
                    prefixIcon: const Icon(Icons.search, size: 32),
                    errorText: _showEmptyQueryHint
                        ? 'Type a title before searching.'
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  key: const Key('discoverSearchButton'),
                  focusNode: _buttonFocus,
                  onPressed: _submit,
                  icon: const Icon(Icons.search, size: 32),
                  label: const Text('Search', style: TextStyle(fontSize: 22)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _screenPadding,
                      vertical: 24,
                    ),
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
