/// Riverpod state for the media discovery flow.
///
/// This is the seam between [MediaDiscoveryRepository] (Task 4) and the TV UI
/// (Tasks 6–7). Nothing here talks to Dio or Jellyseerr: the repository is
/// resolved once through [discoveryRepositoryProvider], and every other
/// provider is either a piece of user-held state or something computed from it.
///
/// The shape is deliberately plain — `StateProvider` for what the user changes,
/// `FutureProvider` for what the repository answers. No custom `Notifier`
/// classes yet; add them only when a flow grows logic that does not fit a
/// single `ref.watch` chain.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../domain/models/media_discovery.dart';
import '../../domain/repositories/media_discovery_repository.dart';

/// The discovery repository, resolved from GetIt.
///
/// `registerDiscoveryServices()` must have run during app startup before this
/// is first read. Tests override it with
/// `discoveryRepositoryProvider.overrideWithValue(fake)` and never touch GetIt.
///
/// Resolved off `GetIt.instance` rather than `lib/di/injection.dart`'s `getIt`
/// alias — same container, but importing that file would drag the whole app
/// graph into a layer that should only depend on `lib/domain/`.
final discoveryRepositoryProvider = Provider<MediaDiscoveryRepository>(
  (_) => GetIt.instance<MediaDiscoveryRepository>(),
);

/// What the user has typed into the search box.
///
/// Held here rather than in a `TextEditingController` so that
/// [searchResultsProvider] can react to it. The UI is expected to debounce
/// before writing, because every write triggers a search.
final searchQueryProvider = StateProvider<String>((_) => '');

/// Search results for the current [searchQueryProvider].
///
/// Re-runs whenever the query changes. An empty (or whitespace-only) query
/// short-circuits to an empty list without touching the repository, so
/// clearing the box costs nothing.
///
/// `autoDispose` because the search screen is transient: leaving it should drop
/// the cached page of results rather than serve them stale on the way back in.
final searchResultsProvider =
    FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return const <SearchResult>[];

  final repository = ref.watch(discoveryRepositoryProvider);
  return repository.searchMedia(query);
});

/// The title the user tapped, or null while nothing is selected.
///
/// Setting this is what drives [availableFilesProvider]; clearing it back to
/// null collapses the file picker to an empty list.
final selectedMediaProvider = StateProvider<SearchResult?>((_) => null);

/// Downloadable releases for [selectedMediaProvider].
///
/// Re-runs whenever the selection changes, and answers an empty list without a
/// network call while nothing is selected.
///
/// `autoDispose` for the same reason as [searchResultsProvider]: seeder counts
/// go stale fast, so a re-entered picker should refetch rather than replay.
final availableFilesProvider =
    FutureProvider.autoDispose<List<FileOption>>((ref) async {
  final selected = ref.watch(selectedMediaProvider);
  if (selected == null) return const <FileOption>[];

  final repository = ref.watch(discoveryRepositoryProvider);
  return repository.getAvailableFiles(selected.id, selected.mediaType);
});

/// The releases the user has ticked in the file picker.
///
/// Replaced wholesale rather than mutated — `StateProvider` compares by
/// identity, so an in-place `add` on the existing list would not notify.
final selectedFilesProvider =
    StateProvider<List<FileOption>>((_) => const <FileOption>[]);

/// Submits the current selection as a Jellyseerr request.
///
/// This is an *action*, not a computation, so it reads its inputs with
/// `ref.read` instead of `ref.watch`: watching would re-submit the request
/// every time the user changed the selection while the result was still on
/// screen, which is exactly the duplicate-request bug this avoids. The
/// repository itself is watched, because it is a stable `Provider`.
///
/// Keyed on `void` so it stays a one-shot family; the result is cached under
/// that single key, so a caller that wants to submit again must invalidate it
/// first:
///
/// ```dart
/// ref.invalidate(submitMediaRequestProvider(null));
/// final request = await ref.read(submitMediaRequestProvider(null).future);
/// ```
///
/// Throws [StateError] when there is nothing to submit. Repository failures
/// (`JellyseerrServiceException`) propagate untouched, so the UI sees them as
/// `AsyncError` and can show the real message.
final submitMediaRequestProvider =
    FutureProvider.family<MediaRequest, void>((ref, _) async {
  final media = ref.read(selectedMediaProvider);
  final files = ref.read(selectedFilesProvider);

  if (media == null || files.isEmpty) {
    throw StateError(
      'A title and at least one file must be selected before requesting.',
    );
  }

  final repository = ref.watch(discoveryRepositoryProvider);
  return repository.requestMedia(media.id, media.mediaType, files);
});
