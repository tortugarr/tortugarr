/// Release picker for the title held in [selectedMediaProvider].
///
/// Reads [availableFilesProvider], groups the releases by [Resolution] and
/// lets the user tick the ones to grab. Submitting sends the selection through
/// [submitMediaRequestProvider] and moves on to the download screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../application/providers/discovery_provider.dart';
import '../../../../domain/models/media_discovery.dart';
import '../discover_routes.dart';

const double _screenPadding = 48;

class FilePickerScreen extends ConsumerStatefulWidget {
  const FilePickerScreen({super.key});

  @override
  ConsumerState<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends ConsumerState<FilePickerScreen> {
  /// True between tapping Request and the backend answering. Keeps a second
  /// tap from firing a duplicate Jellyseerr request.
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(selectedMediaProvider);
    final filesAsync = ref.watch(availableFilesProvider);
    final selected = ref.watch(selectedFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(media?.title ?? 'Choose a release'),
        leading: BackButton(
          key: const Key('filePickerBackButton'),
          onPressed: () => context.go(DiscoverRoutes.results),
        ),
      ),
      body: filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _CenteredMessage(
          key: const Key('filePickerError'),
          icon: Icons.error_outline,
          message: 'Error: $error',
        ),
        data: (files) {
          if (files.isEmpty) {
            return const _CenteredMessage(
              key: Key('filePickerEmpty'),
              icon: Icons.folder_off,
              message: 'No downloadable releases for this title.',
            );
          }
          return _ReleaseList(files: files, selected: selected);
        },
      ),
      bottomNavigationBar: _SubmitBar(
        selectedCount: selected.length,
        submitting: _submitting,
        onSubmit: _submit,
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      // The action provider is a plain (non-autoDispose) family keyed on a
      // single value, so its result is cached. Invalidating first is what
      // makes a resubmit — or a retry after a failure — actually re-run.
      ref.invalidate(submitMediaRequestProvider(null));
      await ref.read(submitMediaRequestProvider(null).future);
      if (!mounted) return;
      context.go(DiscoverRoutes.downloading);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ReleaseList extends ConsumerWidget {
  const _ReleaseList({required this.files, required this.selected});

  final List<FileOption> files;
  final List<FileOption> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = _groupByResolution(files);
    // Highest tier first — Resolution.values runs 720 → 1080 → 2160.
    final tiers = Resolution.values.reversed
        .where(grouped.containsKey)
        .toList(growable: false);

    return ListView.builder(
      key: const Key('filePickerList'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      itemCount: tiers.length,
      itemBuilder: (context, index) {
        final tier = tiers[index];
        final tierFiles = grouped[tier]!;
        return ExpansionTile(
          key: Key('resolutionGroup-${tier.name}'),
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: _screenPadding,
            vertical: 8,
          ),
          title: Text(
            tier.toDisplay(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          subtitle: Text(
            tierFiles.length == 1 ? '1 release' : '${tierFiles.length} releases',
          ),
          children: [
            for (final file in tierFiles)
              CheckboxListTile(
                key: Key('fileOption-${file.path}'),
                value: selected.contains(file),
                onChanged: (checked) => _toggle(ref, file, checked ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: _screenPadding,
                  vertical: 8,
                ),
                title: Text(
                  file.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18),
                ),
                subtitle: Text(
                  '${_formatSize(file)} · ${_formatSeeders(file)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
          ],
        );
      },
    );
  }

  void _toggle(WidgetRef ref, FileOption file, bool checked) {
    final current = ref.read(selectedFilesProvider);
    if (checked == current.contains(file)) return;

    // Replaced wholesale, never mutated: StateProvider compares by identity,
    // so an in-place add on the existing list would not notify.
    ref.read(selectedFilesProvider.notifier).state = checked
        ? <FileOption>[...current, file]
        : current.where((f) => f != file).toList(growable: false);
  }

  static Map<Resolution, List<FileOption>> _groupByResolution(
    List<FileOption> files,
  ) {
    final grouped = <Resolution, List<FileOption>>{};
    for (final file in files) {
      grouped.putIfAbsent(file.resolution, () => <FileOption>[]).add(file);
    }
    // Best-seeded release first inside each tier — that is the one the user
    // almost always wants.
    for (final tier in grouped.values) {
      tier.sort((a, b) => b.seeders.compareTo(a.seeders));
    }
    return grouped;
  }

  static String _formatSize(FileOption file) {
    if (file.sizeInMb < 1024) return '${file.sizeInMb} MB';
    return '${file.sizeInGb.toStringAsFixed(1)} GB';
  }

  static String _formatSeeders(FileOption file) {
    if (!file.hasSeeders) return 'no seeders';
    return file.seeders == 1 ? '1 seeder' : '${file.seeders} seeders';
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.selectedCount,
    required this.submitting,
    required this.onSubmit,
  });

  final int selectedCount;
  final bool submitting;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final enabled = selectedCount > 0 && !submitting;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _screenPadding,
          vertical: 24,
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            key: const Key('filePickerSubmitButton'),
            onPressed: enabled ? onSubmit : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 24),
            ),
            child: Text(
              switch ((submitting, selectedCount)) {
                (true, _) => 'Requesting...',
                (false, 0) => 'Select a release to continue',
                (false, 1) => 'Request 1 release',
                (false, final count) => 'Request $count releases',
              },
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
